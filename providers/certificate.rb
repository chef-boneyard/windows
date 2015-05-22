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

include Chef::Mixin::ShellOut
include Chef::Mixin::PowershellOut
include Windows::Helper

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  # we create from a file...
  file = win_friendly_path(@new_resource.source)
  
  hash = getHashFromFile(file)
  if isCertInStore?(hash)
    Chef::Log.debug("#{@new_resource.source} already exists - nothing to do")
  else
    converge_by("Adding #{ @new_resource.source }") do
      addCertToStore!(file)
      updateAcl!(hash)
    end
  end

end

# acl_add is a modify-if-exists operation : not idempotent
action :acl_add do
  hash = nil

  if ::File.exists?(@new_resource.source)
    # source is a file so get hash from that
    file = win_friendly_path(@new_resource.source)
    hash = getHashFromFile(file)
  else
    # make sure we have no spaces in the hash string
    hash = @new_resource.source.gsub(/\s/, '')
  end
  
  if isCertInStore?(hash)
    converge_by("Adding to ACL of #{hash}") do
      updateAcl!(hash)
    end
  else
    Chef::Log.debug("#{@new_resource.source} does not exist - nothing to do")
  end
end

action :delete do
  # on delete the source should id the cert (subject, hash, serial number etc.)
  if isCertInStore?(@new_resource.source)
    converge_by("Deleting #{ @current_resource.source }") do
      user = " -user" if @new_resource.user_store
      cmd = shell_out!("#{@command}#{user} -delstore #{@new_resource.store_name} \"#{@current_resource.source}\"")
    end
  else
    Chef::Log.debug("#{@new_resource.source} does not exist - nothing to do")
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsCertificate.new(@new_resource.name)
  @current_resource.source(@new_resource.source)
  @current_resource.pfx_password(@new_resource.pfx_password)
  @current_resource.private_key_acl(@new_resource.private_key_acl)
  @current_resource.store_name(@new_resource.store_name)
  @current_resource.user_store(@new_resource.user_store)

  @command = locate_sysnative_cmd("certutil.exe")
end

private
def getHashFromFile(file)
  if file.downcase.end_with?('pfx') && (@new_resource.pfx_password.nil? || @new_resource.pfx_password.empty?)
    raise "No password given for PFX file"
  end
  
  password = " -p #{@new_resource.pfx_password}" if file.downcase.end_with?('pfx')
  cmd = shell_out("#{@command}#{password} \"#{file}\"")
  Chef::Log.debug "certutil reports: #{cmd.stdout}"
  
  # extract values from returned text
  if cmd.exitstatus == 0
    m = cmd.stdout.scan(/Cert Hash\(sha1\): (.+)/)
    if m.length > 0
      # remove spaces from the hash
      m[m.length - 1][0].gsub(/\s/, '')
    else
      raise "Couldn't find hash in output : #{cmd.stdout}"
    end
  else
    raise "certutil returned error #{cmd.exitstatus} : #{cmd.stderr} #{cmd.stdout}"
  end
end

def isCertInStore?(certHash)
  user = " -user" if @new_resource.user_store
  cmd = shell_out("#{@command}#{user} -store #{@new_resource.store_name} \"#{certHash}\"")
  Chef::Log.debug "certutil reports: #{cmd.stdout}"

  cmd.exitstatus == 0
end

def addCertToStore!(file)
  user = " -user" if @new_resource.user_store
  if file.downcase.end_with?('pfx')
    shell_out!("#{@command}#{user} -p #{@new_resource.pfx_password} -importpfx \"#{file}\"")
  else
    shell_out!("#{@command}#{user} -addstore #{@new_resource.store_name} \"#{file}\"")
  end
end

def updateAcl!(certHash)
  if (@new_resource.private_key_acl.nil? || @new_resource.private_key_acl.length == 0)
    return
  end
  
  raise "ACL can only be set on local machine certificates" if @new_resource.user_store
  
  # this PS came from http://blogs.technet.com/b/operationsguy/archive/2010/11/29/provide-access-to-private-keys-commandline-vs-powershell.aspx
  ps_script = "& { $keyname=(((gci cert:\\LocalMachine\\#{@new_resource.store_name} | ? {$_.thumbprint -like '#{certHash}'}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName; "
  ps_script << "if ($keyname -eq $null) { throw 'no private key exists.'; } "
  ps_script << "$fullpath = $env:ProgramData + '\\Microsoft\\Crypto\\RSA\\MachineKeys\\' + $keyname; "
  @new_resource.private_key_acl.each do | name |
    ps_script << "$uname = '#{name}'; "
    ps_script << "icacls $fullpath /grant $uname`:RX; "
  end
  ps_script << "}"

  Chef::Log.debug "Running PS script #{ps_script}"
  p = powershell_out!(ps_script)
  
  if (!p.stderr.nil? && p.stderr.length > 0)
    raise "#{ps_script} failed with #{p.stderr}"
  end
  
  Chef::Log.debug "PS script returned: #{p.stdout}"
end
