# Diagnostic script.
# This script runs a series of diagnostic checks that verify that Windows compute node is
# functioning as expected, given the correct paramters.
# It is safe to run.

Param (
    [Parameter(Mandatory = $false)] [String] $AdapterName = "Ethernet1",
    [Parameter(Mandatory = $false)] [String] $VHostName = "vEthernet (HNSTransparent)",
    [Parameter(Mandatory = $false)] [String] $ForwardingExtensionName = "vRouter forwarding extension",
    [Parameter(Mandatory = $false)] [String] $ContrailLogPath = "C:\ProgramData\Contrail\var\log\contrail\"
)

$VMSwitchName = "Layered?$AdapterName"

function Get-ProperAgentName {
    $Service = Get-Service "contrail-vrouter-agent" -ErrorAction SilentlyContinue
    if ($Service) {
        return "contrail-vrouter-agent"
    } else {
        return "ContrailAgent"
    }
}

function Get-ProperCNMPluginName {
    $Service = Get-Service "contrail-cnm-plugin" -ErrorAction SilentlyContinue
    if ($Service) {
        return "contrail-cnm-plugin"
    } else {
        return "contrail-docker-driver"
    }
}

function Assert-RunningAsAdmin {
    $Principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not($IsAdmin)) {
        Set-TestInconclusive "Test requires administrator privileges"
    }
}

function Assert-ServicePresentAndRunning([string]$Name) {
    { Get-Service $Name -ErrorAction Stop } | Should Not Throw
    # We need to Get-Service again due to script block boundary
    Get-Service $Name | Select-Object -ExpandProperty Status `
        | Should Be "Running"
}

function Assert-AreDLLsPresent {
    Param (
        [Parameter(Mandatory=$true)] $ExitCode
    )
    #https://msdn.microsoft.com/en-us/library/cc704588.aspx
    #Value below is taken from the link above and it indicates
    #that application failed to load some DLL.
    $MissingDLLsErrorReturnCode = [int64]0xC0000135
    $System32Dir = "C:/Windows/System32"

    if ([int64]$ExitCode -eq $MissingDLLsErrorReturnCode) {
        $VisualDLLs = @("msvcp140d.dll", "ucrtbased.dll", "vcruntime140d.dll")
        $MissingVisualDLLs = @()

        foreach($DLL in $VisualDLLs) {
            if (-not (Test-Path $(Join-Path $System32Dir $DLL))) {
                $MissingVisualDLLs += $DLL
            }
        }

        if ($MissingVisualDLLs.count -ne 0) {
            throw "$MissingVisualDLLs must be present in $System32Dir"
        }
        else {
            throw "Some other not known DLL(s) couldn't be loaded"
        }
    }
}

Describe "Diagnostic check" {
    Context "vRouter forwarding extension" {
        It "is running" {
            Assert-RunningAsAdmin
            Get-VMSwitchExtension -Name $ForwardingExtensionName -VMSwitchName $VMSwitchName `
                | Select-Object -ExpandProperty "Running" `
                | Should Be $true
        }

        It "is enabled" {
            Assert-RunningAsAdmin
            Get-VMSwitchExtension -Name $ForwardingExtensionName -VMSwitchName $VMSwitchName `
                | Select-Object -ExpandProperty "Enabled" `
                | Should Be $true
        }

        It "vhost vif is present" {
            $VHostIfAlias = Get-NetAdapter -InterfaceAlias $VHostName `
                | Select-Object -ExpandProperty ifName
            vif.exe --list | Select-String $VHostIfAlias | Should Not BeNullOrEmpty
        }

        It "physical vif is present" {
            $PhysIfAlias = Get-NetAdapter -InterfaceAlias $AdapterName `
                | Select-Object -ExpandProperty ifName
            vif.exe --list | Select-String $PhysIfAlias | Should Not BeNullOrEmpty
        }

        It "pkt0 vif is present" {
            vif.exe --list | Select-String "pkt0" | Should Not BeNullOrEmpty
        }

        It "ksync device is usable using contrail utility" {
            vif.exe --list | Out-Null
            $LASTEXITCODE | Should Be 0
        }

        It "flow device is usable using contrail utility" {
            flow.exe -l | Out-Null
            $LASTEXITCODE | Should Be 0
        }

        It "bridge table device is usable using contrail utility" {
            rt.exe --dump 0 --family bridge | Out-Null
            $LASTEXITCODE | Should Be 0
        }
    }

    Context "vRouter Agent" {
        It "is running" {
            Assert-ServicePresentAndRunning -Name (Get-ProperAgentName)
        }

        It "serves an Agent API on TCP socket" {
            $Result = Test-NetConnection -ComputerName localhost -Port 9091
            $Result.TcpTestSucceeded | Should Be $true
        }

        It "didn't assert or panic lately" {
            $Logs = Get-ChildItem $ContrailLogPath -Filter "*contrail-vrouter-agent*"
            $Output = Select-String -Pattern "Assertion failed" -Path $Logs
            $Output | Should BeNullOrEmpty
        }
    }

    Context "Node manager" {
        It "is running" {
            Assert-ServicePresentAndRunning -Name "contrail-vrouter-nodemgr"
        }
    }

    Context "CNM plugin" {
        It "is running" {
            Assert-ServicePresentAndRunning -Name (Get-ProperCNMPluginName)
        }

        It "creates a named pipe API server" {
            Get-ChildItem "//./pipe/" | Where-Object Name -EQ "Contrail" `
                | Should Not BeNullOrEmpty
        }

        It "serves on named pipe API server" {
            $Stream = $null
            try {
                $Stream = New-Object System.IO.Pipes.NamedPipeClientStream(".", "Contrail")
                $TimeoutMilisecs = 1000
                { $Stream.Connect($TimeoutMilisecs) } | Should Not Throw
            } finally {
                $Stream.Dispose()
            }
        }

        It "has created a root Contrail HNS network in Docker" {
            Assert-RunningAsAdmin
            Get-ContainerNetwork | Where-Object Name -EQ "ContrailRootNetwork" `
                | Should Not BeNullOrEmpty
        }
    }

    Context "Compute node" {
        It "VMSwitch exists" {
            Assert-RunningAsAdmin
            Get-VMSwitch "Layered?$AdapterName" | Should Not BeNullOrEmpty
        }

        It "Visual DLLs are present in C:/Windows/System32 directory" {
            $AGENT_EXECUTABLE_PATH = "C:/Program Files/Juniper Networks/agent/contrail-vrouter-agent.exe"

            $Invocations = @(
                "vif.exe",
                "rt.exe",
                "flow.exe",
                "nh.exe",
                $AGENT_EXECUTABLE_PATH
            )

            foreach ($Invocation in $Invocations) {
                & $Invocation --version 2>&1 | Out-Null
                { Assert-AreDLLsPresent -ExitCode $LastExitCode } | Should Not Throw
            }
        }

        It "can ping Control node from Control interface" {

        }

        It "can ping other Compute node from Dataplane interface" {
            # Optional test
        }

        It "firewall is turned off" {
            # Optional test
            foreach ($Prof in @("Domain", "Public", "Private")) {
                $State = Get-NetFirewallProfile -Profile $Prof `
                    | Select-Object -ExpandProperty Enabled
                if ($State) {
                    $Msg = "Firewall is enabled for profile $Prof - it may break IP fragmentation."
                    Set-TestInconclusive $Msg
                }
            }
            $true | Should Be $true
        }

        It "npcap should not be installed" {
            # npcap (and its kernel drivers) interfere with the way Windows TCP/IP stack
            # works. For example, it disables checksum offloading on container interfaces.
            # To provide a consistent behaviour on test and dev environments, npcap
            # should be uninstalled.
            {
                Get-Service npcap -ErrorAction Stop
            } | Should Throw
        }
    }

    Context "kernel panic" {
        It "there is no recent memory dump" {
            { Get-ChildItem $Env:SystemRoot/MEMORY.DMP -ErrorAction Stop } | Should Throw
        }

        It "there is no recent minidump file" {
            Get-ChildItem C:\Windows\Minidump\*.dmp | Should BeNullOrEmpty
        }
    }

    Context "vRouter certificate" {
        It "test signing is ON" {
            $Output = bcdedit /enum | Select-String 'testsigning' | Select-String 'Yes'
            if ($Output) {
                $true | Should Be $true
            } else {
                $Msg = "Test signing is disabled. Use bcdedit.exe system command to enable it."
                Set-TestInconclusive $Msg
            }
        }

        It "vRouter test certificate is present" {
            $certs = Get-ChildItem -Path cert:\LocalMachine\Root | `
                Where-Object Subject -Match "CN=codilime.com"
            if (!$certs) {
                $Msg = "Test certificate is not imported to cert:\LocalMachine\Root cert store."
                Set-TestInconclusive $Msg
            }

            $certs = Get-ChildItem -Path cert:\LocalMachine\TrustedPublisher | `
                Where-Object Subject -Match "CN=codilime.com"
            if (!$certs) {
                $Msg = "Test certificate is not imported to cert:\LocalMachine\TrustedPublisher cert store."
                Set-TestInconclusive $Msg
            }
        }

        It "vRouter actual certificate is present" {
            # Optional test
        }
    }

    Context "IP fragmentation workaround" {
        It "WinNAT is not running" {
            Get-Service "WinNAT" | Select-Object -ExpandProperty "Status" `
                | Should Be "Stopped"
        }

        It "WinNAT autostart is disabled" {
            Get-Service "WinNAT" | Select-Object -ExpandProperty "Starttype" `
                | Should Be "Disabled"
        }

        It "there is no NAT network" {
            Get-NetNat | Should BeNullOrEmpty
        }
    }

    Context "Docker" {
        It "is running" {
            Assert-ServicePresentAndRunning -Name "Docker"
        }

        It "there are no Contrail networks in Docker with incorrect driver" {
            # After reboot, networks handled by 'Contrail' plugin will instead have 'transparent'
            # plugin assigned. Make sure there are no networks like this.
            $Raw = docker network ls --filter 'driver=transparent'
            $Matches =  $Raw | Select-String "Contrail:.*"

            $Matches.Matches.Count | Should Be 0
        }

        It "there are no orphaned Contrail networks (present in HNS and absent in Docker)" {
            Assert-RunningAsAdmin
            $OwnedNetworks = docker network ls --quiet --filter 'driver=Contrail'
            $ActualHNSNetworks = Get-ContainerNetwork `
                | Where-Object Name -Like "Contrail:*" `
                | Select-Object -ExpandProperty Name
            foreach($HNSNet in $ActualHNSNetworks) {
                # Substring(0, 12) because docker network IDs are shortened to 12 characters.
                $AssociatedDockerNetID = ($HNSNet -split ":")[1].Substring(0, 12)

                $OwnedNetworks -Contains $AssociatedDockerNetID | Should Be $true
            }
        }
    }

    Context "Host Networks Service (HNS) state" {
        It "there are no 'Layered' invalid networks (usually happens after reboot)" {
            Assert-RunningAsAdmin
            $BadNetworks = Get-ContainerNetwork | Where-Object Name -Like "Layered*"
            $BadNetworks | Should BeNullOrEmpty
        }
    }
}
