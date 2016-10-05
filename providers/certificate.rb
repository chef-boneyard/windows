#
# Author:: Richard Lavey (richard.lavey@calastone.com)
# Cookbook Name:: windows
# Provider:: certificate
#
# Copyright:: 2015, Calastone Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

use_inline_resources

# See this for info on certutil
# https://technet.microsoft.com/en-gb/library/cc732443.aspx

include Windows::Helper

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  if @current_resource.exists
    Chef::Log.debug("#{thumbprint(@new_resource.source)} already exists in store - nothing to do.")
  else
    cmd = 'certutil'
    cmd << ' -user' if @new_resource.user_store
    cmd << " -p #{@new_resource.pfx_password}" if @new_resource.pfx_password && @new_resource.type == :pfx
    cmd << (@new_resource.type == :certificate ? ' -addstore' : ' -importPFX')
    cmd << " #{@new_resource.store_name} #{@new_resource.source}"

    Chef::Log.debug(cmd)
    shell_out!(cmd)
    new_resource.updated_by_last_action true
    Chef::Log.info("#{thumbprint(@new_resource.source)} added to store.")
  end
end

# acl_add is a modify-if-exists operation : not idempotent
action :acl_add do
  code_script << acl_script(thumbprint(@new_resource.source))
  guard_script << cert_exists_script(hash)

  powershell_script @new_resource.name do
    guard_interpreter :powershell_script
    convert_boolean_return true
    code code_script
    only_if guard_script
  end
end

action :delete do
  if !@current_resource.exists
    Chef::Log.debug("#{thumbprint(@new_resource.source)} does not exists in store - nothing to do.")
  else
    cmd = 'certutil'
    cmd << ' -user' if @new_resource.user_store # default is LocalMachine
    cmd << " -delstore #{@new_resource.store_name} #{@new_resource.source}"

    Chef::Log.debug(cmd)
    shell_out!(cmd)
    new_resource.updated_by_last_action true
    Chef::Log.info("#{thumbprint(@new_resource.source)} removed from the store.")
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsCertificate.new(@new_resource.name)
  @current_resource.source(@new_resource.source)
  @current_resource.pfx_password(@new_resource.pfx_password)
  @current_resource.private_key_acl(@new_resource.private_key_acl)
  @current_resource.store_name(@new_resource.store_name)
  @current_resource.user_store(@new_resource.user_store)
  @current_resource.type(@new_resource.type)

  # try to determine type from extension for backwards compatability
  @new_resource.type = :pfx if ::File.exist?(@new_resource.source) && ::File.extname(@new_resource.source) == '.pfx'

  if cert_exists?(@new_resource.store_name, @new_resource.source)
    @current_resource.exists = true
  end
end

private

def cert_exists?(store, source)
  Chef::Log.debug "Checking to see if this cert is in the store: '#{thumbprint(source)}'"
  cmd = shell_out("certutil -store #{store} #{thumbprint(source)}")
  cmd.stdout =~ /-store command completed successfully/i
end

def thumbprint(source)
  # If it's not a file assume it's a name or thumbprint
  return unless ::File.exist?(source)

  Chef::Log.debug 'Getting the Thumbprint of the cert'
  file = win_friendly_path(source)
  output = shell_out!("certutil -hashfile #{file}", returns: [0]).stdout

  # Thumbprint is on the second line
  output.split("\n").slice!(1, 1).join('').gsub(/\s+/, '')
end

def cert_exists_script(hash)
  <<-EOH
$hash = #{hash}
Test-Path "Cert:\\#{@location}\\#{@new_resource.store_name}\\$hash"
EOH
end

def acl_script(hash)
  return '' if @new_resource.private_key_acl.nil? || @new_resource.private_key_acl.empty?
  # this PS came from http://blogs.technet.com/b/operationsguy/archive/2010/11/29/provide-access-to-private-keys-commandline-vs-powershell.aspx
  # and from https://msdn.microsoft.com/en-us/library/windows/desktop/bb204778(v=vs.85).aspx
  set_acl_script = <<-EOH
$hash = #{hash}
$storeCert = Get-ChildItem "cert:\\#{@location}\\#{@new_resource.store_name}\\$hash"
if ($storeCert -eq $null) { throw 'no key exists.' }
$keyname = $storeCert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
if ($keyname -eq $null) { throw 'no private key exists.' }
if ($storeCert.PrivateKey.CspKeyContainerInfo.MachineKeyStore)
{
$fullpath = "$Env:ProgramData\\Microsoft\\Crypto\\RSA\\MachineKeys\\$keyname"
}
else
{
$currentUser = New-Object System.Security.Principal.NTAccount($Env:UserDomain, $Env:UserName)
$userSID = $currentUser.Translate([System.Security.Principal.SecurityIdentifier]).Value
$fullpath = "$Env:ProgramData\\Microsoft\\Crypto\\RSA\\$userSID\\$keyname"
}
EOH
  @new_resource.private_key_acl.each do |name|
    set_acl_script << "$uname='#{name}'; icacls $fullpath /grant $uname`:RX\n"
  end
  set_acl_script
end
