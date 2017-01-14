node.default['windows']['feature_provider'] = 'dism'

windows_feature 'TelnetClient' do
  action :install
end

windows_feature 'TFTP-Client' do
  action :install
  provider :windows_feature_powershell
end

windows_feature 'Web-Asp-Net45' do
  action :install
  all    true
  provider :windows_feature_powershell
end
