# We don't support reading the source from the cookbook yet.  So manually point us to
# the correct place in the chef file cache.

windows_certificate "#{Chef::Config[:file_cache_path]}/cookbooks/minimal/files/default/der-cert1.cer" do
  action :create
end

windows_certificate "#{Chef::Config[:file_cache_path]}/cookbooks/minimal/files/default/base64-cert2.cer" do
  action :create
end

windows_certificate '2796bae63f1801e277261ba0d77770028f20eee4' do
  action :delete
end

# Generate using:
# makecert -r -n "CN=ChefDummyCertForTest" -pe -ss My -sv test-cert.pvk test-cert.cer
# pvk2pfx -pvk test-cert.pvk -spc test-cert.cer -pfx test-cert.pfx -po chef123
windows_certificate "#{Chef::Config[:file_cache_path]}/cookbooks/minimal/files/default/test-cert.pfx" do
  action :create
  pfx_password 'chef123'
  store_name 'CA'
end

windows_certificate_binding 'ChefDummyCertForTest' do
  store_name 'CA'
  port 443
end
