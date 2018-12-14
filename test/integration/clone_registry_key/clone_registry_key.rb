describe registry_key('HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319') do
  its('SchUseStrongCrypto') { should eq 1 }
end

describe registry_key('HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\.NETFramework\\v4.0.30319') do
  its('SchUseStrongCrypto') { should eq 1 }
end
