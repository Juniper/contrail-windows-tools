@{
    RootModule = 'ContrailTools.psm1' # psm1 file associated with this psd1 file
    ModuleVersion = '1.0'
    GUID = '7454908e-47a9-4941-9dd7-02b761a4a8d7'
    Author = 'Windows Contrail team'
    CompanyName = 'Juniper Networks, Inc.'
    Copyright = 'Copyright (c) 2018 by Juniper Networks, Inc., licensed under Apache 2.0 License.'
    Description = 'Utility tools for Windows Contrail.'
    PowerShellVersion = '5.0' # Minimal version
    FunctionsToExport = @(
        "Invoke-DiagnosticCheck",
        "Clear-ComputeNode",
        "Invoke-ScriptInRemoteSessions"
    )
}
