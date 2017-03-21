directory 'create test dir' do
  path 'C:\testdir'
  action :create
end

file 'C:\testdir\testfile1' do
  content 'test file 1'
  action :create
end

file 'C:\testdir\testfile2' do
  content 'test file 2'
  action :create
end

windows_zipfile 'C:\test.zip' do
  source 'C:\testdir'
  action :zip
end

directory 'delete test dir' do
  path 'C:\testdir'
  action :delete
  recursive true
end

windows_zipfile 'C:\testdir' do
  source 'C:\test.zip'
  action :unzip
end

windows_zipfile 'C:\test\windows' do
  source 'https://github.com/chef-cookbooks/windows/archive/master.zip'
  action :unzip
end
