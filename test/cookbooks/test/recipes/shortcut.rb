directory 'C:\testdir' do
  action :create
end

windows_shortcut 'C:\test_dir.lnk' do
  target 'C:\testdir'
  description 'Test Dir shortcut'
end
