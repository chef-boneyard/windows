include_recipe 'windows::default'

windows_task 'task_from_name' do
  command 'dir'
end

windows_task 'disable task_from_name' do
  task_name 'task_from_name'
  action :disable
end

windows_task 'create chef\nested task' do
  name 'chef\nested task'
  action :create
  command 'dir'
end

windows_task 'disable chef\nested task' do
  name 'chef\nested task'
  command 'dir /s'
  action :change
end

windows_task 'create long running task loop' do
  task_name '\chef\longtask'
  action :create
  command 'powershell.exe -command while ($true) {start-sleep -seconds 5}'
end

windows_task 'run long running task' do
  task_name '\chef\longtask'
  action :run
end

windows_task 'stop long running task' do
  task_name '\chef\longtask'
  action :end
end

windows_task 'create task to change via create' do
  task_name 'chef\change_me'
  command 'dir'
end

windows_task 'change task change_me via create' do
  task_name 'chef\change_me'
  command 'dir /s'
end

windows_task 'create task delete_me' do
  name 'delete_me'
  user 'NT AUTHORITY\SYSTEM'
  run_level :highest
  password 'ignored'
  action :create
  command 'dir'
  notifies :create, 'file[c:/notifytest.txt]', :immediately
end

windows_task 'delete task delete_me' do
  name 'delete_me'
  action :delete
end

windows_task 'task_for_system' do
  command 'dir'
  run_level :highest
  user 'vagrant'
  password 'vagrant'
  cwd ENV['TEMP']
end

windows_task 'task_on_idle' do
  frequency :on_idle
  command 'dir'
  idle_time 30
end

file 'c:/notifytest.txt' do
  content 'blah'
  action :nothing
end
