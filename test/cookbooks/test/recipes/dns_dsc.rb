# install windows features

windows_feature 'DNS-Server-Full-Role' do
  action :install
end

windows_dns_zone 'chef.local' do
  server_type 'Standalone'
end

# Create an A record
windows_dns_record 'arecord' do
  record_type 'ARecord'
  zone        'chef.local'
  target      '127.0.0.1'
end

# Create a cname
windows_dns_record 'cnamerecord' do
  record_type 'CNAME'
  zone        'chef.local'
  target      'arecord.chef.local'
end
