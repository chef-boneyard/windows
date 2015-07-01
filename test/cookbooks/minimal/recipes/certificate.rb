windows_certificate 'der-cert1.cer' do
  action :create
end

windows_certificate 'base64-cert2.cer' do
  action :create
end

windows_certificate 'cert2.cer' do
  action :delete
end

# Generate using:
# makecert -r -n "CN=ChefDummyCertForTest" -pe -ss My -sv test-cert.pvk test-cert.cer
# pvk2pfx -pvk test-cert.pvk -spc test-cert.cer -pfx test-cert.pfx -po chef123
windows_certificate 'test-cert.pfx' do
  action :create
  pfx_password 'chef123'
end