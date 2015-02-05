#
# Cookbook Name:: windows
# Recipe:: features_ohai_plugin
#
# Author:: Wade Peacock (<wade.peacock@visioncritical.com>)
# Copyright 2015, Vision Critical, Inc
#
# All rights reserved - Do Not Redistribute
#

# This requires your client.rb on the nodes to have the Ohai::Config[:plugin_path] configured

directory node['windows']['ohai_plugins_path'] do
  action :create
  recursive true
end

cookbook_file "#{node['windows']['ohai_plugins_path']}/features.rb" do
  source "features.rb"
  # Not supported for Windows 2003 Server/Windows 2003 Server R2
  not_if { win_version.windows_server_2003_r2? || win_version.windows_server_2003? }
  notifies :reload, "ohai[installed_features]", :immediately
end

ohai "installed_features" do
  action :nothing
end
