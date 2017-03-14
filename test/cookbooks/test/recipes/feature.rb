windows_feature 'TelnetClient' do
  action :install
end

windows_feature 'TFTP-Client' do
  action :install
  install_method :windows_feature_powershell
end

# This is for appveyor, which already seems to have FTP installed
# which causes a short circuit of the "all" behavior and breaks the test.
# TODO: Make :windows_feature_powershell look at all the sub-features and validate
# that they are installed when "all is specified"
windows_feature 'Remove FTP for Appveyor' do
  feature_name 'Web-Ftp-Server'
  action :remove
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
