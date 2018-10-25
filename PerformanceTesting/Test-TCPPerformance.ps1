Param (
    [Parameter(Mandatory = $true)] [string] $ServerComputeNodeIP,
    [Parameter(Mandatory = $true)] [string] $ServerContainerName,
    [Parameter(Mandatory = $true)] [string] $ClientComputeNodeIP,
    [Parameter(Mandatory = $true)] [string] $ClientContainerName,
    [Parameter(Mandatory = $false)] [int] $TestsCount = 10,
    [Parameter(Mandatory = $false)] [pscredential] $Credentials = $(Get-Credential)
)

$WorkingDirectory = "C:\Artifacts"
$NTttcpBinaryName = "NTttcp.exe"
$ResultFileName = "tcpresult.xml"

function Test-Dependencies {
    if (-not $(Test-Path "$PSScriptRoot\$NTttcpBinaryName")) {
        Write-Host "Please copy the $NTttcpBinaryName to the script location."
        Exit
    }
}

function Copy-NTttcp {
    Param (
        [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)] [string] $ContainerName
    )

    Invoke-Command -Session $Session -ScriptBlock {
        New-Item -ItemType Directory -Path $Using:WorkingDirectory -Force | Out-Null
    }

    Copy-Item -ToSession $Session -Path "$PSScriptRoot\$NTttcpBinaryName" -Destination "$WorkingDirectory\$NTttcpBinaryName"

    Invoke-Command -Session $Session -ScriptBlock {
        docker exec ${Using:ContainerName} powershell `
            "New-Item -ItemType Directory -Path ${Using:WorkingDirectory} -Force | Out-Null"

        docker cp "${Using:WorkingDirectory}\${Using:NTttcpBinaryName}" `
            "${Using:ContainerName}:${Using:WorkingDirectory}\${Using:NTttcpBinaryName}"
    }
}

function Get-ContainerIP {
    Param (
        [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $Session,
        [Parameter(Mandatory = $true)] [string] $ContainerName
    )

    return Invoke-Command -Session $Session -ScriptBlock {
        docker exec ${Using:ContainerName} powershell `
            "(Get-NetAdapter | Get-NetIPAddress -AddressFamily IPv4).IPAddress"
    }
}

function Invoke-PerformanceTest {
    Param (
        [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $ServerSession,
        [Parameter(Mandatory = $true)] [string] $ServerContainerName,
        [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $ClientSession,
        [Parameter(Mandatory = $true)] [string] $ClientContainerName,
        [Parameter(Mandatory = $true)] [string] $ServerContainerIP
    )

    Invoke-Command -Session $ServerSession -ScriptBlock {
        docker exec --detach ${Using:ServerContainerName} powershell `
            "${Using:WorkingDirectory}\${Using:NTttcpBinaryName} -r -m 1,*,${Using:ServerContainerIP} -rb 2M -t 15"
    }

    $XMLText = Invoke-Command -Session $ClientSession -ScriptBlock {
        docker exec ${Using:ClientContainerName} powershell `
            "${Using:WorkingDirectory}\${Using:NTttcpBinaryName} -s -m 1,*,${Using:ServerContainerIP} -l 128k -t 15 -xml ${Using:WorkingDirectory}\${Using:ResultFileName} | Out-Null"

        $XMLText = docker exec ${Using:ClientContainerName} powershell `
            "Get-Content ${Using:WorkingDirectory}\${Using:ResultFileName}"

        docker exec ${Using:ClientContainerName} powershell `
            "Remove-Item ${Using:WorkingDirectory}\${Using:ResultFileName}"

        return $XMLText
    }

    return ([xml]$XMLText).ntttcps
}

function Invoke-PerformanceTests {
    Param (
        [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $ServerSession,
        [Parameter(Mandatory = $true)] [string] $ServerContainerName,
        [Parameter(Mandatory = $true)] [System.Management.Automation.Runspaces.PSSession] $ClientSession,
        [Parameter(Mandatory = $true)] [string] $ClientContainerName,
        [Parameter(Mandatory = $true)] [string] $ServerContainerIP,
        [Parameter(Mandatory = $true)] [int] $TestsCount
    )

    $Results = [System.Collections.ArrayList]::new()

    1..$TestsCount | ForEach-Object {
        Write-Host "Running test #$_..."

        $Result = Invoke-PerformanceTest `
            -ServerSession $ServerSession `
            -ServerContainerName $ServerContainerName `
            -ClientSession $ClientSession `
            -ClientContainerName $ClientContainerName `
            -ServerContainerIP $ServerContainerIp

        $Results.Add($Result) | Out-Null
    }

    return $Results
}

class TestRecord {
    [string] ${#}
    [double] ${Mbit/s}
    [double] $Retransmits
    [double] $Errors

    TestRecord($Id, $Mbits, $Retransmits, $Errors) {
        $this.'#' = $Id
        $this.'Mbit/s' = $Mbits
        $this.Retransmits = $Retransmits
        $this.Errors = $Errors
    }

    [void] Add($Mbits, $Retransmits, $Errors) {
        $this.'Mbit/s' += $Mbits
        $this.Retransmits += $Retransmits
        $this.Errors += $Errors
    }

    [void] Div($Cnt) {
        $this.'Mbit/s' /= $Cnt
        $this.Retransmits /= $Cnt
        $this.Errors /= $Cnt
    }
}

function Format-Results {
    Param (
        [Parameter(Mandatory = $true)] [System.Xml.XmlElement[]] $TestsResults
    )

    $Records = [System.Collections.ArrayList]::new()
    $AvgRecord = [TestRecord]::new("AVG", 0, 0, 0)

    for ($i = 0; $i -lt $TestsResults.Length; $i++) {
        $Res = $TestsResults[$i]
        $Mbits = ($Res.throughput | Where-Object { $_.metric -eq "mbps" }).'#text'

        $Record = [TestRecord]::new($i + 1, $Mbits, $Res.packets_retransmitted, $Res.errors)
        $AvgRecord.Add($Mbits, $Res.packets_retransmitted, $Res.errors)

        $Records.Add($Record) | Out-Null
    }

    $AvgRecord.Div($TestsResults.Length)
    $Records.Add($AvgRecord) | Out-Null

    $Records | Format-Table
}

Test-Dependencies

Write-Host "Preparing environment..."
$ServerSession = New-PSSession -ComputerName $ServerComputeNodeIP -Credential $Credentials
$ClientSession = New-PSSession -ComputerName $ClientComputeNodeIP -Credential $Credentials

Copy-NTttcp -Session $ServerSession -ContainerName $ServerContainerName
Copy-NTttcp -Session $ClientSession -ContainerName $ClientContainerName

$ServerContainerIp = Get-ContainerIP -Session $ServerSession -ContainerName $ServerContainerName

$Results = Invoke-PerformanceTests `
    -ServerSession $ServerSession `
    -ServerContainerName $ServerContainerName `
    -ClientSession $ClientSession `
    -ClientContainerName $ClientContainerName `
    -ServerContainerIP $ServerContainerIp `
    -TestsCount $TestsCount

Format-Results -TestsResults $Results
