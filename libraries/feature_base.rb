#
# Author:: Wade Peacock (<wade.peacock@visioncritical.com>)
# Original Author:: ???
# Cookbook Name:: windows
# Library:: feature_base
#
# Copyright:: 2011, Opscode, Inc.
# Copyright:: 2015, Vision Critical, Inc
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

class Chef
  class Provider
    class WindowsFeature
      module Base

        def whyrun_supported?
          true
        end

        def action_install
          unless installed?
            converge_by("Install Feature - #{ @new_resource }") do
              install_feature(@new_resource.feature_name)
              @new_resource.updated_by_last_action(true)
              Chef::Log.info("#{@new_resource} installed feature")
            end
          end
        end

        def action_remove
          if installed?
            converge_by("Remove Feature - #{ @new_resource }") do
              remove_feature(@new_resource.feature_name)
              @new_resource.updated_by_last_action(true)
              Chef::Log.info("#{@new_resource} removed")
            end
          end
        end

        def action_delete
          if available?
            converge_by("Delete Feature - #{ @new_resource }") do
              delete_feature(@new_resource.feature_name)
              @new_resource.updated_by_last_action(true)
              Chef::Log.info("#{@new_resource} deleted")
            end
          end
        end

        def install_feature(name)
          raise Chef::Exceptions::UnsupportedAction, "#{self.to_s} does not support :install"
        end

        def remove_feature(name)
          raise Chef::Exceptions::UnsupportedAction, "#{self.to_s} does not support :remove"
        end

        def delete_feature(name)
          raise Chef::Exceptions::UnsupportedAction, "#{self.to_s} does not support :delete"
        end

        def installed?
          raise Chef::Exceptions::Override, "You must override installed? in #{self.to_s}"
        end

        def available?
          raise Chef::Exceptions::Override, "You must override available? in #{self.to_s}"
        end
      end
    end
  end
end
