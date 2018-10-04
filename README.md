# Compute node scripts

This repository contains utility scripts used for managing Contrail Windows compute nodes.

Hopefully, they should help in operations as well as development.

## Invoke-DiagnosticCheck.ps1

This script runs on localhost and performs a series of checks to verify that Windows compute node
is running correctly. It doesn't introduce any changes, so should be safe to run.

```
.\Invoke-DiagnosticCheck.ps1 -AdapterName "Ethernet0"
```

User must specify command line parameters depending on compute node configuration / deployment
method.

### Deployed via Contrail-Ansible-Deployer

You will need to specify `AdapterName` parameter to value of `WINDOWS_PHYSICAL_INTERFACE`.
Please refer to [official Contrail-Ansible-Deployer example](https://github.com/codilime/contrail-ansible-deployer/blob/master/config/instances.yaml.bms_win_example).

### Deployed in Windows Sanity tests

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
    -AdapterName "Ethernet1" `
    -ForwardingExtensionName "vRouter forwarding extension" `
    -VMSwitchName "Layered Ethernet1" `
    -ConfigAndLogDir "C:\ProgramData\Contrail" `
    -InstallationDir "C:\Program Files\Juniper Networks"
```

All arguments are optional. Default values are demonstrated in the example above.

Arguments `AdapterName`, `ForwardingExtensionName` and `VMSwitchName` refer to: name of physical interface controller by vRouter, name of forwarding extension and name of virtual switch created by vRouter.

## Invoke-ScriptInRemoteSessions.ps1

This script runs a script (specified by `ScriptFileName`) on remote compute nodes described by comma separated list of addresses given in `Addresses` argument (e.g. `"10.0.19.5, 10.0.19.83"`).

Example invocation:
```
.\Clear-RemoteComputeNodes.ps1 `
    -ScriptFileName "Clear-ComputeNode.ps1" `
    -Addresses "127.0.0.1" `
    -IndividualCredentials `
    -SomeExampleArgumentToPass1 "Value1" `
    -SomeExampleArgumentToPass2 "Value2"
```

All arguments are optional. Default values (for `ScriptFileName` and `Addresses`) are demonstrated in the example above.

If `IndividualCredentials` switch is enabled, the script is going to ask for credentials for each given address independently. By default it is assumed, that all remote compute nodes share the same credentials.

All other arguments (`SomeExampleArgumentToPass1` and `SomeExampleArgumentToPass2` in above example) are passed to the invoked script.
