#
# Author:: Blair Hamilton (<blairham@me.com>)
# Cookbook Name:: windows
# Provider:: certificate
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

require 'chef/mixin/shell_out'

include Chef::Mixin::ShellOut

action :add do
  unless @current_resource.exists
    unless File.file?(@new_resource.infile)
      log "Failed to run windows_certificate action :add, #{@new_resource.infile} does not exist" do
      level :warn
    end
    cmd = "certutil -f -addstore #{@new_resource.name} #{@new_resource.infile}"
    Chef::Log.debug(cmd)
    shell_out!(cmd)
    new_resource.updated_by_last_action true
    Chef::Log.info("#{@new_resource.name} added to store.")
  else
    Chef::Log.debug("#{@new_resource.name} already exists in store - nothing to do.")
  end
end

action :delete do
  if @current_resource.exists
    Chef::Application.fatal!("Required attribute cert_id not set") if (@new_resource.cert_id).nil?
    cmd = "certutil -delstore #{@new_resource.name} #{@new_resource.cert_id}"
    Chef::Log.debug(cmd)
    shell_out!(cmd)
    new_resource.updated_by_last_action true
    Chef::Log.info("#{@new_resource.name} removed from store.")
  else
    Chef::Log.debug("#{@new_resource.name} does not exist in store - nothing to do.")
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsCertificate.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  if cert_exists?(@new_resource.name,@new_resource.cert_id)
    @current_resource.exists = true
  end
end

private

def cert_exists?(name,id)
  Chef::Log.debug "Checking to see if this cert is in the store: '#{ name }'"
  cmd = shell_out!("certutil -store #{name} #{id}", {:returns => [0]})
  cmd.stderr.empty? && (cmd.stdout =~ /-store command completed successfully/i)
end
