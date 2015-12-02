#
# Author:: Andrey Rotchev (<arotchev@wildapricot.com>)
# Cookbook Name:: windows
# Provider:: link
# Resource:: link
#
# Copyright:: 2015, WildApricot, Inc.
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

require 'chef/provider/link'
require 'chef/resource/link'
require 'chef/scan_access_control'
if RUBY_PLATFORM =~ /mswin|mingw32|windows/
  require 'chef/win32/error'
  require 'win32/dir'
end

class Chef
  class Provider::WindowsLink < Provider::Link
    def load_current_resource
      # assert that if link_type is :junction that current link type is junction too

      @current_resource = Chef::Resource::WindowsLink.new(@new_resource.name)
      @current_resource.target_file(@new_resource.target_file)
      if file_class.symlink?(@current_resource.target_file)
        @current_resource.link_type(:symbolic)
        @current_resource.to(
          canonicalize(file_class.readlink(@current_resource.target_file))
        )
      elsif ::Dir.junction?(@current_resource.target_file)
        Chef::Log.debug("link #{@current_resource.target_file} is junction")
        @current_resource.link_type(:junction)
        @current_resource.to(
          canonicalize(::Dir.read_junction(@current_resource.target_file))
        )
      else
        @current_resource.link_type(:hard)
        if ::File.exist?(@current_resource.target_file)
          if ::File.exist?(@new_resource.to) && file_class.stat(@current_resource.target_file).ino == file_class.stat(@new_resource.to).ino
            @current_resource.to(canonicalize(@new_resource.to))
          else
            @current_resource.to('')
          end
        end
      end
      Chef::ScanAccessControl.new(@new_resource, @current_resource).set_all!
      @current_resource
    end

    def action_create
      # current_resource is the symlink that currently exists
      # new_resource is the symlink we need to create
      #   to - the location to link to
      #   target_file - the name of the link
      super

      if @new_resource.link_type == :junction &&
         (@current_resource.to != canonicalize(@new_resource.to) || @current_resource.link_type != @new_resource.link_type)
        converge_by("create junction at #{@new_resource.target_file} to #{@new_resource.to}") do
          ::Dir.create_junction(@new_resource.target_file, canonicalize(@new_resource.to))
          Chef::Log.debug("#{@new_resource} created #{@new_resource.link_type} link from #{@new_resource.target_file} -> #{@new_resource.to}")
          Chef::Log.info("#{@new_resource} created")
        end
        if access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
        end
        @new_resource.updated_by_last_action(true)
      end
    end

    def action_delete
      if @current_resource.link_type == :junction
        if @current_resource.to # Exists
          converge_by("delete link at #{@new_resource.target_file}") do
            ::Dir.delete(@new_resource.target_file)
            Chef::Log.info("#{@new_resource} deleted")
          end
        end
      else
        super
      end
    end
  end

  class Resource::WindowsLink < Resource::Link
    def initialize(name, run_context = nil)
      super
      @resource_name = :windows_link
    end

    def link_type(arg = nil)
      real_arg = arg.ia_a?(String) ? arg.to_sym : arg
      set_or_return(
        :link_type,
        real_arg,
        equal_to: [:symbolic, :hard, :junction]
      )
    end
  end
end
