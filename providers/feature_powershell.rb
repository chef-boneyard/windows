#
# Author:: Greg Zapp (<greg.zapp@gmail.com>)
# Cookbook:: windows
# Provider:: feature_powershell
#

use_inline_resources

include Chef::Provider::WindowsFeature::Base
include Chef::Mixin::PowershellOut
include Windows::Helper

def install_feature_cmdlet
  node['os_version'].to_f < 6.2 ? 'Import-Module ServerManager;Add-WindowsFeature' : 'Install-WindowsFeature'
end

def remove_feature_cmdlet
  node['os_version'].to_f < 6.2 ? 'Remove-WindowsFeature' : 'Uninstall-WindowsFeature'
end

def install_feature(_name)
  cmd = powershell_out!("#{install_feature_cmdlet} #{@new_resource.feature_name}")
  Chef::Log.info(cmd.stdout)
end

def remove_feature(_name)
  cmd = powershell_out!("#{remove_feature_cmdlet} #{@new_resource.feature_name}")
  Chef::Log.info(cmd.stdout)
end

def delete_feature(_name)
  cmd = powershell_out!("Uninstall-WindowsFeature #{@new_resource.feature_name} -Remove")
  Chef::Log.info(cmd.stdout)
end

def installed?
  @installed ||= begin
    cmd = powershell_out("Get-WindowsFeature #{@new_resource.feature_name} | Select Installed | % { Write-Host $_.Installed }")
    cmd.stderr.empty? && cmd.stdout =~ /True/i
  end
end

def available?
  @available ||= begin
    cmd = powershell_out("Get-WindowsFeature #{@new_resource.feature_name}")
    cmd.stderr.empty? && cmd.stdout !~ /Removed/i
  end
end
