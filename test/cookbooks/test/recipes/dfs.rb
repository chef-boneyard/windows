directory 'C:\\Test\\Child' do
  recursive true
end

windows_share 'Test' do
  path 'C:\\Test'
end

# install windows features
%w(FS-DFS-Namespace
   RSAT-DFS-Mgmt-Con
   RSAT-File-Services).each do |feature|
  dsc_resource feature do
    resource    :windowsfeature
    property    :name, feature
    property    :ensure, 'Present'
  end
end

windows_dfs 'localhost' do
  action    :configure
  use_fqdn  false
end

windows_dfs_namespace 'prodshare' do
  description 'My Description'
  action      :install
  full_users  ['BUILTIN\\Users']
end

windows_dfs_folder 'Data\\chef\\target' do
  description     'My Description'
  namespace_name  'prodshare'
  target_path     '\\\\localhost\\Test'
  action          :install
end
