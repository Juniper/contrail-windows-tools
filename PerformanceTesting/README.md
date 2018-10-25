# Testing network performance

## Testing TCP performance

1. Prepare 2 containers according to selected scenario, e.g.:

    * 2 containers in single network on single compute node
    * 2 containers in different networks on single compute node
    * 2 containers in single network on different compute nodes
    * 2 containers in different networks on different compute nodes

2. Run `Test-TCPPerformance.ps1 <IP1> <CN1> <IP2> <CN2> [TestsCount] [Cred]`, where:

    * `<IP1>` is an IP address of compute node with first container,
    * `<IP2>` is an IP address of compute node with second container,
    * `<CN1>` is a name or ID of first container,
    * `<CN2>` is a name or ID of second container,
    * `[TestsCount]` is an optional number of tests to perform (default = 10),
    * `[Cred]` is optional credentials argument - credentials prompt will be displayed if not provided.
