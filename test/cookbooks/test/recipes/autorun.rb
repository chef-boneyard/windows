include_recipe 'windows::default'

windows_auto_run 'notepad' do
  program 'C:/windows/system32/notepad.exe'
  action  :create
end

windows_auto_run 'notepad' do
  program 'C:/windows/system32/notepad.exe'
  action  :remove
end
