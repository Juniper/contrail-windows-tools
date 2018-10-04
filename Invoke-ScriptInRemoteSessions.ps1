Param (
    [Parameter(Mandatory = $false)] [String] $ScriptFileName = "Clear-ComputeNode.ps1",
    [Parameter(Mandatory = $false)] [String] $Addresses = "127.0.0.1",
    [Parameter(Mandatory = $false)] [Switch] $IndividualCredentials,
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)] $ArgumentsToPass
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

function Invoke-ScriptInSessions {
    Param (
        [Parameter(Mandatory=$true)] [String] $ScriptFileName,
        [Parameter(Mandatory=$true)] [System.Management.Automation.Runspaces.PSSession[]] $Sessions
    )

    foreach ($Session in $Sessions) {
        try {
            Write-Host "Copying script to remote session: $($Session.ComputerName) ..."
            Copy-Item -ToSession $Session -Path $ScriptFileName -Destination "C:\$ScriptFileName" -ErrorAction Stop
            Write-Host "Running script '$ScriptFileName' in remote session: $($Session.ComputerName) ..."
            Invoke-Command -Session $Session -ErrorAction Stop -ScriptBlock {
                function Invoke-ScriptWithParameters {
                    Param (
                        [Parameter(Mandatory = $true)] $ScriptFileName,
                        [Parameter(Mandatory = $true)] [AllowNull()] $Parameters
                    )
                    
                    $ParametersString = ""
                    foreach($Parameter in $Parameters) {
                        if (-not $Parameter.Contains(" ")) {
                            $ParametersString += "$Parameter "
                        } else {
                            $ParametersString += "'$Parameter' "
                        }
                    }
                    $Expression = "./$ScriptFileName $ParametersString"
                    Write-Host $Expression
                    Invoke-Expression $Expression
                }

                Set-Location C:\
                Invoke-ScriptWithParameters `
                    -ScriptFileName $Using:ScriptFileName `
                    -Parameters $Using:ArgumentsToPass
            }
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)"
        }
    }
}

$Sessions = New-Sessions -Addresses $Addresses.Split(",")
Invoke-ScriptInSessions -ScriptFileName $ScriptFileName -Sessions $Sessions
Close-Sessions -Sessions $Sessions
