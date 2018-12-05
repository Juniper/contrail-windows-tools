# Contrail Windows tools

This repository contains utility scripts used for managing Contrail Windows compute nodes.

Hopefully, they should help in operations as well as development.

It is recommended to install ContrailTools module (see [Installation](#installation)), but 
some scripts can also be ran directly after download (see [Quick run](#quick_run)).

## Installation

First, install [PSGet](https://github.com/psget/psget):

```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/psget/psget/master/GetPsGet.ps1 | Invoke-Expression
```

Then, install Contrail tools module:

```
Install-Module -ModuleUrl https://github.com/Juniper/contrail-windows-tools/archive/master.zip
```

## Quick run

The following snippets will run a script directly after downloading it from the Internet.

### Run diagnostic check

```
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/Juniper/contrail-windows-tools/master/Invoke-DiagnosticCheck.ps1 | Invoke-Expression
```

### Run cleanup

```
Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/Juniper/contrail-windows-tools/master/Clear-ComputeNode.ps1 | Invoke-Expression
```

## Useful snippets

### Run diagnostic check on multiple Windows nodes

```
Invoke-ScriptInRemoteSessions.ps1 -ScriptFileName ".\Invoke-DiagnosticCheck.ps1" -Addresses "<IP1>,<IP2>" -Credential (Get-Credential)
```

### Clear multiple Windows nodes

```
Invoke-ScriptInRemoteSessions.ps1 -ScriptFileName ".\Clear-ComputeNode.ps1" -Addresses "<IP1>,<IP2>" -Credential (Get-Credential)
```

# Scripts description 

## Invoke-DiagnosticCheck.ps1

This script runs on localhost and performs a series of checks to verify that Windows compute node
is running correctly. It doesn't introduce any changes, so should be safe to run.

**Note**: the script can be ran with or without Administrator privileges. However, some checks
will not be performed without them.

```
.\Invoke-DiagnosticCheck.ps1 -AdapterName "Ethernet0"
```

User must specify command line parameters depending on compute node configuration / deployment
method.

**Deployed via Contrail-Ansible-Deployer**

You will need to specify `AdapterName` parameter to value of `WINDOWS_PHYSICAL_INTERFACE`.
Please refer to [official Contrail-Ansible-Deployer example](https://github.com/codilime/contrail-ansible-deployer/blob/master/config/instances.yaml.bms_win_example).

**Deployed in Windows Sanity tests**

You will need to specify `AdapterName`, `VHostName` and `forwardingExtensionName` parameters to
their equivalent field under `system` section in `testenv-conf.yaml` file:

```
...
system:
  adapterName: Ethernet1
  vHostName: vEthernet (HNSTransparent)
  forwardingExtensionName: vRouter forwarding extension
...
```
## Clear-ComputeNode.ps1

This script:

1. Uninstalls all components of Tungsten Fabric.
2. Removes all services created during installation.
3. Uninstalls all docker images, removes all containers and Docker networks.
4. Removes all HNS networks.
5. Removes installation directory and directories with logs and configuration files.

All operations are executed on a local machine.

Example invocation:
```
.\Clear-ComputeNode.ps1 `
    -ConfigAndLogDir "C:\ProgramData\Contrail" `
    -InstallationDir "C:\Program Files\Juniper Networks"
```

All arguments are optional. Default values are demonstrated in the example above.

## Invoke-ScriptInRemoteSessions.ps1

This script runs a script (specified by `ScriptFileName`) on remote compute nodes described by comma separated list of addresses given in `Addresses` argument (e.g. `"10.0.19.5,10.0.19.83"`).

Example invocation:
```
.\Invoke-ScriptInRemoteSessions.ps1 `
    -ScriptFileName "Clear-ComputeNode.ps1" `
    -Addresses "127.0.0.1" `
    -IndividualCredentials `
    -SomeExampleArgumentToPass1 "Value1" `
    -SomeExampleArgumentToPass2 "Value2"
```

All arguments are optional. Default values (for `ScriptFileName` and `Addresses`) are demonstrated in the example above.

If `IndividualCredentials` switch is enabled, the script is going to ask for credentials for each given address independently. By default it is assumed, that all remote compute nodes share the same credentials.

All other arguments (`SomeExampleArgumentToPass1` and `SomeExampleArgumentToPass2` in above example) are passed to the invoked script.

## Testing network performance

Read more [here](PerformanceTesting/README.md).
