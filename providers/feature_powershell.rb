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
  node['os_version'].to_f < 6.2 ? 'Import-Module ServerManager; Add-WindowsFeature' : 'Install-WindowsFeature'
end

def remove_feature_cmdlet
  node['os_version'].to_f < 6.2 ? 'Import-Module ServerManager; Remove-WindowsFeature' : 'Uninstall-WindowsFeature'
end

def install_feature(_name)
  addall = @new_resource.all ? '-IncludeAllSubFeature' : ''
  cmd = powershell_out!("#{install_feature_cmdlet} #{to_array(@new_resource.feature_name).join(',')} #{addall}")
  Chef::Log.info(cmd.stdout)
end

def remove_feature(_name)
  cmd = powershell_out!("#{remove_feature_cmdlet} #{to_array(@new_resource.feature_name).join(',')}")
  Chef::Log.info(cmd.stdout)
end

def delete_feature(_name)
  cmd = powershell_out!("Uninstall-WindowsFeature #{to_array(@new_resource.feature_name).join(',')} -Remove")
  Chef::Log.info(cmd.stdout)
end

def installed?
  @installed ||= begin
    cmd = powershell_out("(Get-WindowsFeature #{to_array(@new_resource.feature_name).join(',')} | ?{$_.InstallState -ne \'Installed\'}).count")
    cmd.stderr.empty? && cmd.stdout.chomp.to_i.zero?
  end
end

def available?
  @available ||= begin
    cmd = powershell_out("(Get-WindowsFeature #{to_array(@new_resource.feature_name).join(',')} | ?{$_.InstallState -ne \'Removed\'}).count")
    cmd.stderr.empty? && cmd.stdout.chomp.to_i > 0
  end
end
