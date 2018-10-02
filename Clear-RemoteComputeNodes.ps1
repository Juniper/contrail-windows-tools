Param (
    [Parameter(Mandatory=$false)] [String] $ScriptFileName = "Clear-ComputeNode.ps1",
    [Parameter(Mandatory=$false)] [String] $Addresses = "127.0.0.1",
    [Parameter(Mandatory=$false)] [Switch] $IndividualCredentials,
    [Parameter(Mandatory = $false)] [String] $AdapterName = "Ethernet1",
    [Parameter(Mandatory = $false)] [String] $ForwardingExtensionName = "vRouter forwarding extension",
    [Parameter(Mandatory = $false)] [String] $VMSwitchName = "Layered Ethernet1",
    [Parameter(Mandatory = $false)] [String] $ConfigAndLogDir = "C:\ProgramData\Contrail",
    [Parameter(Mandatory = $false)] [String] $InstallationDir = "C:\Program Files\Juniper Networks"
)

function New-Sessions {
    Param (
        [Parameter(Mandatory=$true)] [String[]] $Addresses,
        [Parameter(Mandatory=$false)] [Int] $RetryCount = 10,
        [Parameter(Mandatory=$false)] [Int] $Timeout = 300000
    )

    if ($IndividualCredentials -eq $false) {
        $Credential = Get-Credential -Message "Enter common credentials for compute nodes"
    }

    Write-Host "Creating Powershell sessions..."
    $Sessions = @()
    foreach ($Address in $Addresses) {
        try {
            if ($IndividualCredentials -eq $true) {
                $Credential = Get-Credential -Message "Enter credentials for $Address"
            }
            $PSO = New-PSSessionOption -MaxConnectionRetryCount $RetryCount -OperationTimeout $Timeout -ErrorAction Stop
            $Session = New-PSSession -ComputerName $Address -Credential $Credential -SessionOption $PSO -ErrorAction Stop
            $Sessions += $Session
            Write-Host "Session created: $($Session.ComputerName)"
        } catch {
            Write-Host "ERROR: Failed to create session for remote compute node: $Address. Skipping this compute node."
        }
        
    }
    return $Sessions
}

function Close-Sessions {
    Param ([Parameter(Mandatory=$true)] [System.Management.Automation.Runspaces.PSSession[]] $Sessions)

    Write-Host "Closing Powershell sessions..."
    foreach ($Session in $Sessions) {
        Remove-PSSession -Session $Session
    }
}

function Run-ScriptInSessions {
    Param (
        [Parameter(Mandatory=$true)] [String] $ScriptFileName,
        [Parameter(Mandatory=$true)] [System.Management.Automation.Runspaces.PSSession[]] $Sessions
    )

    foreach ($Session in $Sessions) {
        try {
            Write-Host "Copying script to remote session: $($Session.ComputerName) ..."
            Copy-Item -ToSession $Session -Path $ScriptFileName -Destination "C:\$ScriptFileName" -ErrorAction Stop
            Write-Host "Running script '$ScriptFileName' in remote session: $($Session.ComputerName) ..."
            $Response = Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {
                Set-Location C:\
                &./$Using:ScriptFileName `
                    -AdapterName $Using:AdapterName `
                    -ForwardingExtensionName $Using:ForwardingExtensionName `
                    -VMSwitchName $Using:VMSwitchName `
                    -ConfigAndLogDir $Using:ConfigAndLogDir `
                    -InstallationDir $Using:InstallationDir
            }
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)"
        }
    }
}

$Sessions = New-Sessions -Addresses $Addresses.Split(",")
Run-ScriptInSessions -ScriptFileName $ScriptFileName -Sessions $Sessions
Close-Sessions -Sessions $Sessions
