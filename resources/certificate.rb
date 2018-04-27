#
# Author:: Richard Lavey (richard.lavey@calastone.com)
# Cookbook:: windows
# Resource:: certificate
#
# Copyright:: 2015-2017, Calastone Ltd.
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

property :source, String, name_property: true
property :pfx_password, String
property :private_key_acl, Array
property :store_name, String, default: 'MY', equal_to: ['TRUSTEDPUBLISHER', 'TrustedPublisher', 'CLIENTAUTHISSUER', 'REMOTE DESKTOP', 'ROOT', 'TRUSTEDDEVICES', 'WEBHOSTING', 'CA', 'AUTHROOT', 'TRUSTEDPEOPLE', 'MY', 'SMARTCARDROOT', 'TRUST', 'DISALLOWED']
property :user_store, [true, false], default: false

action :create do
  add_cert_in_certstore
end

# acl_add is a modify-if-exists operation : not idempotent
action :acl_add do
  if ::File.exist?(new_resource.source)
    hash = '$cert.GetCertHashString()'
    code_script = cert_script(false)
    guard_script = cert_script(false)
  else
    # make sure we have no spaces in the hash string
    hash = "\"#{new_resource.source.gsub(/\s/, '')}\""
    code_script = ''
    guard_script = ''
  end
  code_script << acl_script(hash)
  guard_script << cert_exists_script(hash)

  powershell_script "setting the acls on #{new_resource.source} in #{cert_location}\\#{new_resource.store_name}" do
    guard_interpreter :powershell_script
    convert_boolean_return true
    code code_script
    only_if guard_script
  end
end

action :delete do
  delete_cert_from_certstore
end

action_class do
  include Windows::Helper
  include ::Win32::Helper

  def add_cert_in_certstore
    add_cert(openssl_cert_obj)
  end

  def delete_cert_from_certstore
    delete_cert
  end

  def cert_location
    @location ||= new_resource.user_store ? 'CurrentUser' : 'LocalMachine'
  end

  def cert_script(persist)
    cert_script = '$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2'
    file = win_friendly_path(new_resource.source)
    cert_script << " \"#{file}\""
    if ::File.extname(file.downcase) == '.pfx'
      cert_script << ", \"#{new_resource.pfx_password}\""
      if persist && new_resource.user_store
        cert_script << ', ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)'
      elsif persist
        cert_script << ', ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeyset)'
      end
    end
    cert_script << "\n"
  end

  def cert_exists_script(hash)
    <<-EOH
  $hash = #{hash}
  Test-Path "Cert:\\#{cert_location}\\#{new_resource.store_name}\\$hash"
  EOH
  end

  def within_store_script
    inner_script = yield '$store'
    <<-EOH
  $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "#{new_resource.store_name}", ([System.Security.Cryptography.X509Certificates.StoreLocation]::#{cert_location})
  $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
  #{inner_script}
  $store.Close()
  EOH
  end

  def acl_script(hash)
    return '' if new_resource.private_key_acl.nil? || new_resource.private_key_acl.empty?
    # this PS came from http://blogs.technet.com/b/operationsguy/archive/2010/11/29/provide-access-to-private-keys-commandline-vs-powershell.aspx
    # and from https://msdn.microsoft.com/en-us/library/windows/desktop/bb204778(v=vs.85).aspx
    set_acl_script = <<-EOH
  $hash = #{hash}
  $storeCert = Get-ChildItem "cert:\\#{cert_location}\\#{new_resource.store_name}\\$hash"
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
    new_resource.private_key_acl.each do |name|
      set_acl_script << "$uname='#{name}'; icacls $fullpath /grant $uname`:RX\n"
    end
    set_acl_script
  end
end
