template node['windows']['upgrade_script_location'] do
  source 'chef-upgrade.ps1.erb'
  only_if { can_upgrade_to?(node['windows']['chef_msi_location'])}
end
