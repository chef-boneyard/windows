directory 'C:\path_test_path'

windows_path 'C:\path_test_path' do
  action :add
end

directory 'c:\path_test_another_path'

windows_path 'C:\path_test_another_path' do
  action :add
end