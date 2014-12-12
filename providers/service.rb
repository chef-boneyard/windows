#
# Author:: Blair Hamilton (<blairham@me.com>)
# Cookbook Name:: windows
# Provider:: service
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

action :create do
  unless @current_resource.exists
    cmd = "sc create #{@new_resource.name} binPath= #{@new_resource.binary_path}"
    cmd << " type= #{@new_resource.type}" if @new_resource.type
    cmd << " start= #{@new_resource.start}" if @new_resource.start
    cmd << " DisplayName= #{@new_resource.display_name}" if @new_resource.display_name
    Chef::Log.debug(cmd)
    shell_out!(cmd)
    new_resource.updated_by_last_action true
    Chef::Log.info("#{@new_resource.name} created")
  else
    Chef::Log.debug("#{@new_resource} already exists - nothing to do")
  end
end

action :delete do
  if @current_resource.exists
    cmd = "sc delete #{@new_resource.name}"
    Chef::Log.debug(cmd)
    shell_out!(cmd)
    new_resource.updated_by_last_action true
    Chef::Log.info("#{@new_resource.name} deleted")
  else
    Chef::Log.debug("#{@new_resource} does not exists - nothing to do")
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsService.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  service_hash = load_service_hash(@current_resource.name)
  if service_hash[:SERVICE_NAME] == @new_resource.name
    @current_resource.running = running?(@new_resource.name) ? true : false
    @current_resource.exists = true
    @current_resource.binary_path(service_hash[:BINARY_PATH_NAME])
    @current_resource.display_name(service_hash[:DISPLAY_NAME])
  end if service_hash.respond_to? :[]
end

private

def running?(service_name)
  cmd = shell_out!("sc query #{service_name} | FIND \"STATE\" | FIND \"RUNNING\"", {:returns => [0,1]})
  cmd.stderr.empty? && (cmd.stdout =~ /RUNNING/i)
end

def load_service_hash(service_name)
  output = shell_out("sc qc #{ service_name }").stdout

  if output =~ /SUCCESS/i
    service = Hash.new

    output.split("\n").map! do |line|
      line.split(":").map! do |field|
        field.strip
      end
    end.each do |field|
      if field.kind_of? Array and field[0].respond_to? :to_sym
        service[field[0].gsub(/\s+/,"").to_sym] = field[1]
      end
    end
  else
    service = false
  end

  service
end