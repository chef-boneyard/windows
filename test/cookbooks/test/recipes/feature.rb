# pass feature name as a string
windows_feature 'install SNMP' do
  feature_name 'SNMP'
end

# pass feature name as an array
windows_feature 'remove SNMP' do
  feature_name ['SNMP']
  action :remove
end

# pass feature name as a lowercase value on 2012+
windows_feature 'Install SNMP again' do
  feature_name node['platform_version'].to_f < 6.2 ? 'SNMP' : 'snmp' # lowercase on purpose
end

# array of feature names
windows_feature_dism %w(TelnetClient TFTP)

# This is for appveyor, which already seems to have FTP installed
# which causes a short circuit of the "all" behavior and-breaks the test.
# TODO: Make :windows_feature_powershell look at all the sub-features and validate
# that they are installed when "all is specified"
windows_feature 'Remove FTP for Appveyor' do
  feature_name 'Web-Ftp-Server'
  action :remove
  install_method :windows_feature_powershell
  not_if { node['platform_version'].to_f < 6.2 }
end

# lowercase install for windows 2012+, but proper case for 2k8r2 because...it's old
windows_feature 'install Web-Ftp-Server' do
  feature_name 'Web-Ftp-Server'
  feature_name node['platform_version'].to_f < 6.2 ? 'Web-Ftp-Server' : 'web-ftp-server'
  all true
  install_method :windows_feature_powershell
end

# These aren't available on ancient windows so don't test there
unless node['platform_version'].to_f < 6.2
  # commas separated list of features (not an array)
  windows_feature_powershell 'Web-Asp-Net45, Web-Net-Ext45'

  windows_feature ['NPAS'] do
    management_tools true
    install_method :windows_feature_powershell
  end
end
