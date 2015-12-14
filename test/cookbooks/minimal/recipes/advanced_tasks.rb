windows_advanced_task 'Exec task with boot trigger and 30 min time trigger with 5min splay' do
  action :create
  user 'SYSTEM'
  logon_type :service_account
  exec_actions 'Path' => 'cmd.exe', 'WorkingDirectory' => 'C:\\', 'Arguments' => '/C echo "test"'
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446815
  triggers 'Type' => :boot, 'Delay' => 'PT0M', 'Enabled' => true
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa383622
  triggers 'Type' => :time, 'RandomDelay' => 'PT5M', 'Enabled' => true, 'StartBoundary' => '2015-08-01T00:00:00', 'Repetition' => { 'Interval' => 'PT30M' }
end

windows_advanced_task 'Task with many triggers running only daily' do
  action :create
  user 'vagrant'
  password 'vagrant'
  logon_type :password
  exec_actions 'Path' => 'dir', 'WorkingDirectory' => 'C:\\'
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa446858
  triggers 'Type' => :daily, 'DaysInterval' => 2, 'Enabled' => true, 'RandomDelay' => 'PT0M', 'StartBoundary' => '2015-08-01T00:00:00'
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa384019
  triggers 'Type' => :monthly, 'DaysOfMonth' => 0x7FFFFFFF, 'MonthsOfYear' => 0xFFF, 'RunOnLastDayOfMonth' => false, 'Enabled' => false, 'StartBoundary' => '2015-08-01T00:00:00'
  # https://msdn.microsoft.com/en-us/library/windows/desktop/aa382062
  triggers 'Type' => :weekly, 'WeeksInterval' => 2, 'DaysOfWeek' => 0x55, 'Enabled' => false, 'StartBoundary' => '2015-08-01T00:00:00'
end
