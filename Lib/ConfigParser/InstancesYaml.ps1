function New-ComputeSessionsFromInstancesYaml {
    Param ([Parameter(Mandatory=$true)] [string] $PathToYaml)

    $Parsed = Read-Yaml $PathToYaml

    $Username = $Parsed.provider_config.bms_win.ansible_user
    $PlainTextPassword = $Parsed.provider_config.bms_win.ansible_password
    $Password = $PlainTextPassword | ConvertTo-SecureString -AsPlainText -Force
    $ComputeIPs = $Parsed.Instances.Keys `
        | Where-Object { $Parsed.Instances[$_].Provider -eq "bms_win" } `
        | ForEach-Object { $Parsed.Instances[$_].ip }

    # TODO: Domain name should be handled consistently here and in CI.
    $DomainAndUsername = "WORKGROUP\" + $Username
    $Creds = New-Object System.Management.Automation.PSCredential($DomainAndUsername, $Password)
    $Sessions = $ComputeIPs | ForEach-Object { New-PSSession $_ -Credential $Creds }

    return $Sessions
}

function Get-WinPhysIfnameFromInstancesYaml {
    Param ([Parameter(Mandatory=$true)] [string] $PathToYaml)

    $Parsed = Read-Yaml $PathToYaml
    return $Parsed.contrail_configuration.WINDOWS_PHYSICAL_INTERFACE
}

function Read-Yaml {
    Param ([Parameter(Mandatory=$true)] [string] $PathToYaml)
    $Parsed = ConvertFrom-Yaml (Get-Content -Raw $PathToYaml)
    return $Parsed
}
