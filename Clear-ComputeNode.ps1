Param (
    [Parameter(Mandatory = $false)] [String] $AdapterName = "Ethernet1",
    [Parameter(Mandatory = $false)] [String] $ForwardingExtensionName = "vRouter forwarding extension",
    [Parameter(Mandatory = $false)] [String] $VMSwitchName = "Layered Ethernet1",
    [Parameter(Mandatory = $false)] [String] $ConfigAndLogDir = "C:\ProgramData\Contrail",
    [Parameter(Mandatory = $false)] [String] $InstallationDir = "C:\Program Files\Juniper Networks"
)

function Stop-ProcessIfExists {
    Param ([Parameter(Mandatory = $true)] [string] $ProcessName)

    $Proc = Get-Process $ProcessName -ErrorAction SilentlyContinue
    if ($Proc) {
        $Proc | Stop-Process -Force -PassThru | Wait-Process -ErrorAction Stop
    }
}

function Remove-HNSNetworks {
    Write-Host "Cleaning HNS state..."
    try {
        Get-NetNat | Remove-NetNat -Confirm:$false
        # Two tries are intentional - it's workaround for HNS behavior.
        Get-ContainerNetwork | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Remove-ContainerNetwork -ErrorAction Stop -Force
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-NodeMgrService {
    Write-Host "Stopping Node Manager and removing service..."
    try {
        $NodeMgrServiceName = "contrail-vrouter-nodemgr"
        $Service = Get-Service $NodeMgrServiceName -ErrorAction SilentlyContinue
        if ($Service -ne $null) {
            Stop-Service $NodeMgrServiceName -ErrorAction Stop
            sc.exe delete $NodeMgrServiceName
            if ($LASTEXITCODE -ne 0) {
                throw "sc.exe failed to delete service."
            }
        }
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-AgentService {
    Write-Host "Stopping Agent and removing service..."
    try {
        $AgentServiceName = "ContrailAgent"
        $Service = Get-Service $AgentServiceName -ErrorAction SilentlyContinue
        if ($Service -ne $null) {
            Stop-Service $AgentServiceName -ErrorAction Stop
            sc.exe delete $AgentServiceName
            if ($LASTEXITCODE -ne 0) {
                throw "sc.exe failed to delete service."
            }
        }
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-DockerDriverService {
    Write-Host "Stopping Docker Driver and removing service..."
    try {
        $DockerDriverServiceName = "contrail-docker-driver"
        $Service = Get-Service $DockerDriverServiceName -ErrorAction SilentlyContinue
        if ($Service -ne $null) {
            Stop-Service $DockerDriverServiceName -ErrorAction Stop
            sc.exe delete $DockerDriverServiceName
            if ($LASTEXITCODE -ne 0) {
                throw "sc.exe failed to delete service."
            }
        }
        # Docker Driver may run as a service. Or not.
        Stop-ProcessIfExists -ProcessName "contrail-windows-docker-driver"
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Disable-VRouterExtension {
    Param (
        [Parameter(Mandatory = $true)] [String] $AdapterName,
        [Parameter(Mandatory = $true)] [String] $ForwardingExtensionName,
        [Parameter(Mandatory = $true)] [String] $VMSwitchName
    )
    Write-Host "Disabling Extension..."
    try {
        Disable-VMSwitchExtension -VMSwitchName $VMSwitchName -Name $ForwardingExtensionName -ErrorAction Stop | Out-Null
        # Two tries are intentional - it's workaround for HNS behavior.
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $AdapterName | Remove-ContainerNetwork -ErrorAction SilentlyContinue -Force
        Get-ContainerNetwork | Where-Object NetworkAdapterName -eq $AdapterName | Remove-ContainerNetwork -ErrorAction Stop -Force
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-AllContainers {
    Write-Host "Removing all containers..."
    try {
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
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-NotUsedDockerNetworks {
    Write-Host "Removing not used Docker networks..."
    docker network prune --force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: This step failed. Trying to continue, but final result is unpredictable."
    }
}

function Uninstall-Components {
    Write-Host "Uninstalling components..."
    $Failures = 0
    @(Get-WmiObject Win32_product `
        -Filter "name='Agent' OR name='vRouter' OR name='vRouter utilities' OR name='Contrail Docker Driver'") `
        | ForEach-Object {
            msiexec.exe /x $_.IdentifyingNumber /q
            if ($LASTEXITCODE -ne 0) {
                $Failures += 1
            }
        }
    if ($Failures -ne 0) {
        Write-Host "    ERROR: This step failed. Trying to continue, but final result is unpredictable."
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
    try {
        Remove-Item $ConfigAndLogDir -Force -Recurse -ErrorAction Stop
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Remove-InstallationDirectory {
    Param ([Parameter(Mandatory = $true)] [String] $InstallationDir)

    Write-Host "Removing installation directory..."
    try {
        Remove-Item $InstallationDir -Force -Recurse -ErrorAction Stop
    } catch {
        $ErrorMessage += $_.Exception.Message
        Write-Host "    This step failed with the following error message: $ErrorMessage"
        Write-Host "    Trying to continue, but final result is unpredictable."
    }
}

function Clear-ComputeNode {
    Param (
        [Parameter(Mandatory = $true)] [String] $AdapterName,
        [Parameter(Mandatory = $true)] [String] $ForwardingExtensionName,
        [Parameter(Mandatory = $true)] [String] $VMSwitchName,
        [Parameter(Mandatory = $true)] [String] $ConfigAndLogDir,
        [Parameter(Mandatory = $true)] [String] $InstallationDir
    )

    Remove-NodeMgrService
    Remove-AgentService
    Remove-DockerDriverService

    Disable-VRouterExtension `
        -AdapterName $AdapterName `
        -ForwardingExtensionName $ForwardingExtensionName `
        -VMSwitchName $VMSwitchName

    Start-Service docker
    Remove-AllContainers
    Remove-NotUsedDockerNetworks
    Uninstall-Components
    Remove-AllDockerImages
    Remove-ConfigAndLogDir -ConfigAndLogDir $ConfigAndLogDir
    Remove-InstallationDirectory -InstallationDir $InstallationDir
    Stop-Service docker
    Remove-HNSNetworks
    Start-Service docker
}

Clear-ComputeNode `
    -AdapterName $AdapterName `
    -ForwardingExtensionName $ForwardingExtensionName `
    -VMSwitchName $VMSwitchName `
    -ConfigAndLogDir $ConfigAndLogDir `
    -InstallationDir $InstallationDir
