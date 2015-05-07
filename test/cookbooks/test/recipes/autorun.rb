windows_auto_run 'add notepad' do
  name 'notepad'
  program 'C:/windows/system32/notepad.exe'
  action :create
end

windows_auto_run 'remove notepad' do
  name 'notepad'
  program 'C:/windows/system32/notepad.exe'
  root :machine
  action :remove
end

windows_auto_run 'add wordpad' do
  name 'wordpad'
  program 'C:\Windows\System32\write.exe'
  root 'user'
  action :create
end
