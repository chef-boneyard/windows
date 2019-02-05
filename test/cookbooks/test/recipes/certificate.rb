# We don't support reading the source from the cookbook yet.  So manually point us to
# the correct place in the chef file cache.

directory 'C:/certs'

cookbook_file 'C:/certs/GeoTrust_Primary_CA.pem' do
  source 'GeoTrust_Primary_CA.pem'
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

cookbook_file 'C:/certs/DigiCertAssuredIDCAG2.crt' do
  source 'DigiCertAssuredIDCAG2.crt'
end

cookbook_file 'C:/certs/test-cert.pfx' do
  source 'test-cert.pfx'
end

cookbook_file 'C:/certs/test-pfx-certificate.pfx' do
  source 'test-pfx-certificate.pfx'
end

cookbook_file 'C:/certs/test_p7b.p7b' do
  source 'test_p7b.p7b'
end

cookbook_file 'C:/certs/ThawteRSACA2018.crt' do
  source 'ThawteRSACA2018.crt'
end

cookbook_file 'C:/certs/GeoTrust_Universal_CA.pem' do
  source 'GeoTrust_Universal_CA.pem'
end

# Add (.PEM) format certificate in MY certificate store (no private key)
windows_certificate 'C:/certs/GeoTrust_Primary_CA.pem' do
  action :create
end

# delete certificate by thumbprint from MY certificate store
windows_certificate '323C118E1BF7B8B65254E2E2100DD6029037F096' do
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
  source 'C:/certs/DigiCertAssuredIDCAG2.crt'
end

# delete certificate by thumbprint with colon from MY certificate store
windows_certificate 'delete certificate by thumbprint with colon' do
  source '28:e9:6c:db:1d:ba:27:3f:d1:a6:15:1b:e1:5f:08:8f:26:04:62:73'
  action :delete
end

# Add (.PFX) format certificate with password in CA certificate store
windows_certificate 'C:/certs/test-cert.pfx' do
  action :create
  pfx_password 'chef123'
  store_name 'CA'
end

# Add (.PFX) format certificate with password including special character( e.g. @, $)
windows_certificate 'C:/certs/test-pfx-certificate.pfx' do
  action :create
  pfx_password 'chef$123'
  store_name 'MY'
end

# delete certificate by thumbprint from CA certificate store
windows_certificate '50 81 f6 67 f1 ef 00 5d 0e c3 9f a3 e3 0a a7 1b 4f d8 4e b6' do
  action :delete
  store_name 'CA'
end

# (.P7B) format certificate in CA certificate store
windows_certificate 'add .p7b certificate' do
  action :create
  source 'C:/certs/test_p7b.p7b'
  store_name 'CA'
end

# delete certificate by thumbprint from MY certificate store
windows_certificate 'delete certificate by thumbprint with space' do
  source 'b1 bc 96 8b d4 f4 9d 62 2a a8 9a 81 f2 15 01 52 a4 1d 82 9c'
  action :delete
  store_name 'CA'
end

# Install PFX certificate with private key
windows_certificate 'C:/certs/test-cert.pfx' do
  action :create
  pfx_password 'chef123'
end

# Add (.CRT) format certificate for validation tests
windows_certificate 'add .crt certificate' do
  action :create
  source 'C:/certs/ThawteRSACA2018.crt'
end

# Validate certificate by thumbprint
windows_certificate '4DEEA7060D80BABF1643B4E0F0104C82995075B7' do
  action :verify
end

# Validate certificate by thumbprint with space
windows_certificate '9E 84 8F 52 57 5C 6B 1A 69 D6 AB 62 E0 28 8B FA D4 A5 56 4E' do
  action :verify
end

# Validate certificate by thumbprint with colon
windows_certificate 'validate certificate' do
  action :verify
  source '9E:84:8F:52:57:5C:6B:1A:69:D6:AB:62:E0:28:8B:FA:D4:A5:56:4E'
end

# Validate certificate by invalid thumbprint
windows_certificate 'validate certificate' do
  action :verify
  source '9E:84:8F:52:57:5C:6B:1A:69:D6:AB:62:E0:28:8B:FA:D4:A5:56:4E:1'
end

# Add (.PEM) format certificate for fetch and export tests
windows_certificate 'C:/certs/GeoTrust_Universal_CA.pem' do
  action :create
end

# Fetch certificate and display on console in PEM format
windows_certificate 'E621F3354379059A4B68309D8A2F74221587EC79' do
  action :fetch
end

# Export certificate in PEM
windows_certificate 'E6 21 F3 35 43 79 05 9A 4B 68 30 9D 8A 2F 74 22 15 87 EC 79' do
  action :fetch
  cert_path 'C:\certs\demo.pem'
end

# Export certificate in DER
windows_certificate 'E6:21:F3:35:43:79:05:9A:4B:68:30:9D:8A:2F:74:22:15:87:EC:79' do
  action :fetch
  cert_path 'C:\certs\demo.der'
end

# Export certificate in CER
windows_certificate 'Export certificate in cer' do
  action :fetch
  source 'E6 21 F3 35 43 79 05 9A 4B 68 30 9D 8A 2F 74 22 15 87 EC 79'
  cert_path 'C:\certs\demo.cer'
end

# Export certificate in CRT
windows_certificate 'E6 21 F3 35 43 79 05 9A 4B 68 30 9D 8A 2F 74 22 15 87 EC 79' do
  action :fetch
  cert_path 'C:\certs\demo.crt'
end

# Export certificate in PFX with no keys
windows_certificate 'E6 21 F3 35 43 79 05 9A 4B 68 30 9D 8A 2F 74 22 15 87 EC 79' do
  action :fetch
  cert_path 'C:\certs\demo.pfx'
end

# Export certificate in P7B
windows_certificate 'E6 21 F3 35 43 79 05 9A 4B 68 30 9D 8A 2F 74 22 15 87 EC 79' do
  action :fetch
  cert_path 'C:\certs\demo.p7b'
end

# Export certificate in invalid format return error
windows_certificate 'E6 21 F3 35 43 79 05 9A 4B 68 30 9D 8A 2F 74 22 15 87 EC 79' do
  action :fetch
  cert_path 'C:\certs\demo.mp3'
end

# delete certificate that is not installed
windows_certificate '50 AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA AA' do
  action :delete
  store_name 'CA'
end
