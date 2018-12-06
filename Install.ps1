# This script is called automatically by Install-Module cmdlet, e.g. when:
# Install-Module -ModuleUrl https://github.com/Juniper/contrail-windows-tools/archive/master.zip

$InstallDir = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module $InstallDir\ContrailTools.psd1

# Install dependencies
Install-Module -ModuleUrl "https://github.com/cloudbase/powershell-yaml/archive/master.zip"
