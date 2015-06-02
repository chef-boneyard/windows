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

# See this for info on certutil
# https://technet.microsoft.com/en-gb/library/cc732443.aspx

include Windows::Helper

# Support whyrun
def whyrun_supported?
  true
end

use_inline_resources

action :create do
  # We can do everything in a powershell script resource
  file = win_friendly_path(@new_resource.source)
  isPfx = file.downcase.end_with?('pfx')
  password = ", \"#{@new_resource.pfx_password}\"" if isPfx
  persistKeySet = ', ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)' if isPfx

  codeScript = <<-EOH
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "#{@new_resource.store_name}", ([System.Security.Cryptography.X509Certificates.StoreLocation]::#{@location})
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 "#{file}"#{password}#{persistKeySet}
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($cert)
    $store.Close()
    #{getAclScript('$cert.GetCertHashString()')}
  EOH
  notifScript = <<-EOH
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 "#{file}"#{password}
    Test-Path "cert:\\#{@location}\\#{@new_resource.store_name}\\$($cert.GetCertHashString())"
  EOH
  
  powershell_script @new_resource.name do
    code codeScript
    not_if notifScript
  end
end

# acl_add is a modify-if-exists operation : not idempotent
action :acl_add do
  # We can do everything in a powershell script resource
  hash = nil

  if ::File.exists?(@new_resource.source)
    # source is a file so get hash from that
    file = win_friendly_path(@new_resource.source)
    password = ", \"#{@new_resource.pfx_password}\"" if file.downcase.end_with?('pfx')
    hash = "(New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 \"#{file}\"#{password}).GetCertHashString()"
  else
    # make sure we have no spaces in the hash string
    hash = "\"#{@new_resource.source.gsub(/\s/, '')}\""
  end
  
  codeScript = <<-EOH
    #{getAclScript(hash)}
  EOH
  onlyifScript = <<-EOH
    $hash = #{hash}
    Test-Path "cert:\\#{@location}\\#{@new_resource.store_name}\\$hash"
  EOH
  
  powershell_script @new_resource.name do
    code codeScript
    only_if onlyifScript
  end
end

action :delete do
  # do we have a hash or a subject?
  search = nil
  if m = @new_resource.source.match(/^[a-fA-F0-9]{40}$/)
    search = "Thumbprint -eq '#{@new_resource.source}'"
  else
    search = "Subject -like '*#{@new_resource.source.sub(/\*/, '`*')}*'" # escape any * in the source
  end
  certCommand = "gci cert:\\#{@location}\\#{@new_resource.store_name} | where { $_.#{search} }"
  
  codeScript = <<-EOH
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "#{@new_resource.store_name}", ([System.Security.Cryptography.X509Certificates.StoreLocation]::#{@location})
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    foreach ($c in #{certCommand})
    {
      $store.Remove($c)
    }
    $store.Close()
  EOH
  onlyifScript = <<-EOH
    @(#{certCommand}).Count -gt 0
  EOH
  
  # We can do everything in a powershell script resource
  powershell_script @new_resource.name do
    code codeScript
    only_if onlyifScript
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsCertificate.new(@new_resource.name)
  @current_resource.source(@new_resource.source)
  @current_resource.pfx_password(@new_resource.pfx_password)
  @current_resource.private_key_acl(@new_resource.private_key_acl)
  @current_resource.store_name(@new_resource.store_name)
  @current_resource.user_store(@new_resource.user_store)
  @location = @current_resource.user_store ? 'CurrrentUser' : 'LocalMachine'
end

private
def getAclScript(hash)
  if (!@new_resource.private_key_acl.nil? && @new_resource.private_key_acl.length > 0)
    raise "ACL can only be set on local machine certificates" if @new_resource.user_store

    # this PS came from http://blogs.technet.com/b/operationsguy/archive/2010/11/29/provide-access-to-private-keys-commandline-vs-powershell.aspx
    setAclScript = <<-EOH
      $hash = #{hash}
      $storeCert = gci "cert:\\#{@location}\\#{@new_resource.store_name}\\$hash"
      if ($storeCert -eq $null) { throw 'no key exists.' } 
      $keyname = $storeCert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
      if ($keyname -eq $null) { throw 'no private key exists.' } 
      $fullpath = "$env:ProgramData\\Microsoft\\Crypto\\RSA\\MachineKeys\\$keyname"
    EOH
    @new_resource.private_key_acl.each do | name |
      setAclScript << "$uname='#{name}'; icacls $fullpath /grant $uname`:RX;"
    end
    
    setAclScript
  end
end
