include_recipe 'windows::default'

user 'space user' do
  password 'Pass@word1'
end

windows_http_acl 'http://google.com:80/' do
  user "#{ENV['COMPUTERNAME']}\\space user"
end
