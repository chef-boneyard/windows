# We don't support reading the source from the cookbook yet.  So manually point us to
# the correct place in the chef file cache.

directory 'C:/certs'

cookbook_file 'C:/certs/GlobalSignRootCA.pem' do
  source 'GlobalSignRootCA.pem'
end

cookbook_file 'C:/certs/test_der.der' do
  source 'test_der.der'
end

cookbook_file 'C:/certs/der-cert1.cer' do
  source 'der-cert1.cer'
end

cookbook_file 'C:/certs/base64-cert2.cer' do
  source 'base64-cert2.cer'
end

cookbook_file 'C:/certs/test_cert.crt' do
  source 'test_cert.crt'
end

cookbook_file 'C:/certs/test-cert.pfx' do
  source 'test-cert.pfx'
end

cookbook_file 'C:/certs/test_p7b.p7b' do
  source 'test_p7b.p7b'
end

# Add (.PEM) format certificate in MY certificate store
windows_certificate 'C:/certs/GlobalSignRootCA.pem' do
  action :create
end

# delete certificate by thumbprint from MY certificate store
windows_certificate 'b1bc968bd4f49d622aa89a81f2150152a41d829c' do
  action :delete
end

# Add (.DER) format certificate in MY certificate store
windows_certificate 'add DER format certificate' do
  source 'C:/certs/test_der.der'
  action :create
end

# delete certificate by thumbprint from MY certificate store
windows_certificate 'delete certificate by thumbprint with space' do
  source 'b1 bc 96 8b d4 f4 9d 62 2a a8 9a 81 f2 15 01 52 a4 1d 82 9c'
  action :delete
end

# Add (.CER) DER encoded binary X.509 certificate in MY certificate store
windows_certificate 'C:/certs/der-cert1.cer' do
  action :create
end

# Add (.CER) Base64 encoded X.509 certificate in ROOT certificate store
windows_certificate 'C:/certs/base64-cert2.cer' do
  action :create
  store_name 'CA'
end

# Add (.CRT) format certificate in MY certificate store
windows_certificate 'add .crt certificate' do
  action :create
  source 'C:/certs/test_cert.crt'
end

# delete certificate by thumbprint with colon from MY certificate store
windows_certificate 'delete certificate by thumbprint with colon' do
  source 'b1:bc:96:8b:d4:f4:9d:62:2a:a8:9a:81:f2:15:01:52:a4:1d:82:9c'
  action :delete
end

# Add (.PFX) format certificate with password in CA certificate store
windows_certificate 'C:/certs/test-cert.pfx' do
  action :create
  pfx_password 'chef123'
  store_name 'CA'
end

# delete certificate by thumbprint from CA certificate store
windows_certificate '50 81 f6 67 f1 ef 00 5d 0e c3 9f a3 e3 0a a7 1b 4f d8 4e b6' do
  action :delete
  store_name 'CA'
end

# (.P7B) format certificate in MY certificate store
windows_certificate 'add .p7b certificate' do
  action :create
  source 'C:/certs/test_p7b.p7b'
  store_name 'MY'
end

# delete certificate by thumbprint from MY certificate store
windows_certificate 'delete certificate by thumbprint with space' do
  source 'b1 bc 96 8b d4 f4 9d 62 2a a8 9a 81 f2 15 01 52 a4 1d 82 9c'
  action :delete
end

windows_certificate 'C:/certs/test-cert.pfx' do
  action :create
  pfx_password 'chef123'
  store_name 'CA'
end
