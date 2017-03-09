windows_auto_run 'add notepad' do
  name 'notepad'
  program 'C:/windows/system32/notepad.exe'
  action  :create
end

windows_auto_run 'remove notepad' do
  name 'notepad'
  program 'C:/windows/system32/notepad.exe'
  action  :remove
end
