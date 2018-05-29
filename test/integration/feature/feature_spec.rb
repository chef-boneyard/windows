describe windows_feature('SNMP Service') do
  it { should be_installed }
end

describe windows_feature('Web-Ftp-Server') do
  it { should be_installed }
end

describe windows_feature('Web-Asp-Net45') do
  it { should be_installed }
end

describe windows_feature('Web-Net-Ext45') do
  it { should be_installed }
end

describe windows_feature('NPAS') do
  it { should be_installed }
end
