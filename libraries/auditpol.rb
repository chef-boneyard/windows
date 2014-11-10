# Encoding: utf-8
# Author:: Dave Viebrock (<dave.viebrock@nordstrom.com>)
# Cookbook Name:: windows
# Provider:: windows_auditpol
#
# Copyright:: 2014, Nordstrom, Inc.
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

module Windows
  module Auditpol

    def auditpol
      @auditpol ||= begin
        locate_sysnative_cmd("auditpol.exe")
      end
    end

    def ensure_objectaccess_type
      category = '"Object Access"'
      strip_category = category.gsub!('\'','')
      subcategory = new_resource.subcategory
	  @ensure_objectacess ||= begin
        cmd = shell_out!("#{auditpol} /get /category:#{category}", returns: [0])
        Chef::Log.debug "The Object Access policy type validation category query value is: #{cmd.stdout}"
        unless cmd.stderr.empty? && cmd.stdout.include?("#{strip_category}")
          Chef::Log.fatal "The Auditpol subcategory must be of the 'Object Access' type!  You used: #{strip_category}"
		end
      end
    end

    def desiredstate_exists?(subcategory)
      subcategory = new_resource.subcategory
      Chef::Log.debug "Checking for desired state of #{subcategory}"
      success = new_resource.success
      failure = new_resource.failure
	  case
	  when success.include?('enable') && failure.include?('enable')
	    state = 'Success and Failure'
      when success.include?('disable') && failure.include?('enable')
	    state = 'Failure'
      when success.include?('enable') && failure.include?('disable')
	    state = 'Success'
      when success.include?('disable') && failure.include?('disable')
        state = 'No Auditing'
      end      
      Chef::Log.debug "Checking for existing local policy subcategory configuration:#{subcategory}, success:#{success}, failure:#{failure}"
      Chef::Log.debug "Expected auditpol state is: #{state}"
	  
	  @exists ||= begin
        cmd = shell_out!("#{auditpol} /get /subcategory:#{subcategory}", returns: [0])
        Chef::Log.debug "Auditpol query value for current setting is #{cmd.stdout}"
        cmd.stderr.empty? && cmd.stdout.include?("#{state}")
      end
    end

    def set_auditpol_subcategory
      subcategory = new_resource.subcategory
      success = new_resource.success
      failure = new_resource.failure

	  Chef::Log.info "Setting local policy subcategory configuration required for: #{subcategory}, success:#{success}, failure:#{failure}"
      cmd = shell_out!("#{auditpol} /set /subcategory:#{subcategory} /success:#{success} /failure:#{failure}", returns: [0])
      Chef::Log.debug "Auditpol /set command results: #{cmd.stdout}"
    end
  end
end
