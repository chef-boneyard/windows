ruby_block 'end chef run' do
  block do
    raise Windows::ChefUpdateHelper::UpgradeRequested
  end
  action :nothing
end

template Windows::ChefUpdateHelper::windows_path(node['windows']['upgrade_script_location']) do
  source 'chef-update.ps1.erb'
  only_if { Windows::ChefUpdateHelper::can_upgrade_to?(node['windows']['chef_msi_location'])}
  notifies :create, 'windows_task[upgrade chef]', :immediately
end

windows_task 'upgrade chef' do
  execute_time = Time.now + node['windows']['upgrade_in_seconds']

  frequency :once
  command "#{ENV['SystemRoot']}\\System32\\WindowsPowershell\\v1.0\\powershell.exe -NoLogo -NonInteractive -File '#{Windows::ChefUpdateHelper::windows_path(node['windows']['upgrade_script_location'])}'"
  start_day Windows::ChefUpdateHelper::format_start_day(execute_time.month, execute_time.day, execute_time.year)
  start_time Windows::ChefUpdateHelper::format_start_time(execute_time.hour, execute_time.min)
  run_level :highest
  action :nothing
  notifies :run, 'ruby_block[end chef run]'
end
