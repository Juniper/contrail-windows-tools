# Testing network performance

## Testing TCP performance

1. Prepare 2 containers according to selected scenario. Refer to performance test
[documentation](https://juniper.github.io/contrail-windows-docs/For%20developers/Developer%20guide/Performance/Testing/).

2. Download NTttcp and place the binary in this directory.

```
Invoke-WebRequest https://gallery.technet.microsoft.com/NTttcp-Version-528-Now-f8b12769/file/159655/1/NTttcp-v5.33.zip -OutFile NTttcp-v5.33.zip
New-Item -Type Directory NTttcp
Expand-Archive .\NTttcp-v5.33.zip -OutputPath NTttcp
Copy-Item NTttcp\amd64fre\NTttcp.exe .
```

2. Run `Test-TCPPerformance.ps1` script, where:

```
.\Test-TCPPerformance.ps1 `
    -SenderComputeNodeIP 10.7.0.122 `
    -SenderContainerName sender `
    -ReceiverComputeNodeIP 10.7.0.123 `
    -ReceiverContainerName receiver
    # OPTIONAL: -TestsCount 10 `
    # OPTIONAL: -Credentials $Creds
```

where:

* `SenderComputeNodeIP` is an IP address of compute node with first container,
* `ReceiverComputeNodeIP` is an IP address of compute node with second container,
* `SenderContainerName` is a name or ID of first container,
* `ReceiverContainerName` is a name or ID of second container,
* `TestsCount` is an optional number of tests to perform (default = 10),
* `Credentials` is optional credentials argument - credentials prompt will be displayed if not provided.
