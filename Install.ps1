# This script is called automatically by Install-Module cmdlet, e.g. when:
# Install-Module -ModuleUrl https://github.com/Juniper/contrail-windows-tools/raw/master/ContrailTools.psd1

$InstallDir = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module $InstallDir\ContrailTools.psd1
