node.default['windows']['feature_provider'] = 'dism'

windows_feature 'TelnetClient' do
  action :install
end
