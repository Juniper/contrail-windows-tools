@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ContrailTools.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0'
    
    # ID used to uniquely identify this module
    GUID = '7454908e-47a9-4941-9dd7-02b761a4a8d7'
    
    # Author of this module
    Author = 'Windows Contrail team'
    
    # Company or vendor of this module
    CompanyName = 'Juniper'
    
    # Copyright statement for this module
    Copyright = 'Copyright (c) 2018 by Juniper Team, licensed under Apache 2.0 License.'
    
    # Description of the functionality provided by this module
    Description = 'Utility tools for Windows Contrail.'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'
    
    # Functions to export from this module
    FunctionsToExport = @(
        "Invoke-DiagnosticCheck",
        "Clear-ComputeNode",
        "Invoke-ScriptInRemoteSessions"
    )
}
