
# create directory for sharing with full access for all users
directory 'c:/test_share' do
  rights  :full_control, 'BUILTIN\\Users'
end

windows_share 'read_only' do
  path            'C:/test_share'
  description     'a test share'
  read_users      ['BUILTIN\\Users']
end

windows_share 'change' do
  path            'C:/test_share'
  change_users    ['BUILTIN\\Users']
end

windows_share 'full' do
  path            'C:/test_share'
  full_users ['BUILTIN\\Users']
end

# create then delete the share
windows_share 'create no_share' do
  share_name      'no_share'
  path            'C:/test_share'
end

windows_share 'no_share' do
  action          :delete
end

# create share then change path
windows_share 'create changed_dir' do
  share_name      'changed_dir'
  path            'C:/'
end

windows_share 'alter changed_dir' do
  share_name      'changed_dir'
  path            'C:/test_share'
end
