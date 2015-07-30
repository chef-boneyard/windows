remote_file 'C:\\Firefox Setup 5.0.exe' do
  source 'http://archive.mozilla.org/pub/mozilla.org/mozilla.org/firefox/releases/5.0/win32/en-US/Firefox%20Setup%205.0.exe'
end

windows_package 'Mozilla Firefox 5.0 (x86 en-US)' do
  source 'file:///C:/Firefox Setup 5.0.exe'
  options '-ms'
  installer_type :custom
  action :install
end
