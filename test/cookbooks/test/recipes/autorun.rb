windows_auto_run 'add notepad' do
  program_name 'notepad'
  path 'C:\windows\system32\notepad.exe'
  action :create
end

windows_auto_run 'remove notepad' do
  program_name 'notepad'
  root :machine
  action :remove
end

windows_auto_run 'add wordpad' do
  program_name 'wordpad'
  program 'C:/Windows/System32/write.exe' # the legacy name for the path property
  root :user
  action :create
end
