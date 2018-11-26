Param (
    [Parameter(Mandatory = $false)] [String] $ConfigAndLogDir = "C:\ProgramData\Contrail",
    [Parameter(Mandatory = $false)] [String] $InstallationDir = "C:\Program Files\Juniper Networks",
    [Parameter(Mandatory = $false)] [switch] $KeepContainerImages
)

function Invoke-ScriptBlockAndPrintExceptions {
    Param (
        [Parameter(Mandatory=$true, Position=0)] [ScriptBlock] $ScriptBlock
    )

    try {
        Invoke-Command $ScriptBlock
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-NetNatObjects {
    Write-Host "Removing NetNat..."
    Invoke-ScriptBlockAndPrintExceptions {
        Get-NetNat | Remove-NetNat -Confirm:$false
    }
}

function Remove-HNSNetworks {
    Write-Host "Cleaning HNS state..."
    Invoke-ScriptBlockAndPrintExceptions {
        # Two tries are intentional - it's workaround for HNS behavior.
        Get-ContainerNetwork | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Remove-ContainerNetwork -ErrorAction Stop -Force
    }
}

function Remove-Service {
    Param ([Parameter(Mandatory = $true)] [String] $ServiceName)

    Write-Host "Stopping $ServiceName and removing service..."
    Invoke-ScriptBlockAndPrintExceptions {
        $Service = Get-Service $ServiceName -ErrorAction SilentlyContinue
        if ($Service -ne $null) {
            Stop-Service $ServiceName -ErrorAction Stop
            sc.exe delete $ServiceName
            if ($LASTEXITCODE -ne 0) {
                throw "sc.exe failed to delete service."
            }
        }
    }
}

function Remove-AllContainers {
    Write-Host "Removing all containers..."
    Invoke-ScriptBlockAndPrintExceptions {
        $Containers = docker ps -aq
        $MaxAttempts = 3
        $TimesToGo = $MaxAttempts
        if ($Containers.length -gt 0) {
            while ( $Containers -and $TimesToGo -gt 0 ) {
                if($Containers) {
                    docker rm -f $Containers
                    $Containers = docker ps -aq
                    if ($Containers.length -gt 0 -and $TimesToGo -eq 0) {
                        throw "Some containers could not be deleted."
                    }
                }
                $Containers = docker ps -aq
                $TimesToGo = $TimesToGo - 1
            }
        }
    }
}

function Remove-NotUsedDockerNetworks {
    Write-Host "Removing not used Docker networks..."
    docker network prune --force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: This step failed. Trying to continue, but final result is unpredictable."
    }
}

function Uninstall-MSIs {
    Write-Host "Uninstalling MSIs..."
    $Failures = 0
    @(Get-WmiObject Win32_product `
        -Filter "name='Agent' OR name='vRouter' OR name='vRouter utilities' OR name='Contrail CNM Plugin' OR name='Contrail Docker Driver'") `
        | ForEach-Object {
            Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/quiet", "/x", $_.IdentifyingNumber
            if ($LASTEXITCODE -ne 0) {
                $Failures += 1
            }
        }
    if ($Failures -ne 0) {
        Write-Host "    ERROR: This step failed. Trying to continue, but final result is unpredictable."
    }
}

function Uninstall-PythonPackages {
    Write-Host "Uninstalling Python packages..."
    $Packages = (
        "nodemgr",
        "sandesh",
        "sandesh-common",
        "vrouter",
        "database"
    )
    ForEach ($p in $Packages) {
        pip uninstall $p --yes 2> $null
    }
}

function Remove-AllDockerImages {
    Write-Host "Removing all Docker images..."
    $Images = docker images -aq
    $LASTEXITCODE = 0
    if ($Images.length -gt 0) {
        docker rmi $Images
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: This step failed. Trying to continue, but final result is unpredictable."
    }
}

function Remove-ConfigAndLogDir {
    Param ([Parameter(Mandatory = $true)] [String] $ConfigAndLogDir)

    Write-Host "Removing directory with configuration files and logs..."
    Invoke-ScriptBlockAndPrintExceptions {
        Remove-Item $ConfigAndLogDir -Force -Recurse -ErrorAction Stop
    }
}

function Remove-InstallationDirectory {
    Param ([Parameter(Mandatory = $true)] [String] $InstallationDir)

    Write-Host "Removing installation directory..."
    Invoke-ScriptBlockAndPrintExceptions {
        Remove-Item $InstallationDir -Force -Recurse -ErrorAction Stop
    }
}

function Clear-ComputeNode {
    Param (
        [Parameter(Mandatory = $true)] [String] $ConfigAndLogDir,
        [Parameter(Mandatory = $true)] [String] $InstallationDir
    )

    Remove-Service -ServiceName "contrail-vrouter-nodemgr"
    Remove-Service -ServiceName "ContrailAgent"             # legacy name
    Remove-Service -ServiceName "contrail-vrouter-agent"
    Remove-Service -ServiceName "contrail-docker-driver"    # legacy name
    Remove-Service -ServiceName "contrail-cnm-plugin"

    Stop-Service docker
    Remove-NetNatObjects
    Remove-HNSNetworks

    Start-Service docker
    Remove-AllContainers
    Remove-NotUsedDockerNetworks
    Uninstall-MSIs
    Uninstall-PythonPackages
    if (-not ($KeepContainerImages)) {
        Remove-AllDockerImages
    }
    Remove-ConfigAndLogDir -ConfigAndLogDir $ConfigAndLogDir
    Remove-InstallationDirectory -InstallationDir $InstallationDir
}

Clear-ComputeNode `
    -ConfigAndLogDir $ConfigAndLogDir `
    -InstallationDir $InstallationDir
