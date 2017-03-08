windows_feature 'TelnetClient' do
  action :install
end

windows_feature 'TFTP-Client' do
  action :install
  install_method :windows_feature_powershell
end

windows_feature 'Web-Ftp-Server' do
  action :install
  all    true
  install_method :windows_feature_powershell
end

windows_feature ['Web-Asp-Net45', 'Web-Net-Ext45'] do
  action :install
  install_method :windows_feature_powershell
end
