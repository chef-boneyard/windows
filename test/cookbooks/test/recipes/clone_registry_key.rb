registry_key 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319' do
  values [{
    name: 'SchUseStrongCrypto',
    type: :dword,
    data: 1,
  }]
end

windows_clone_registry_key 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Wow6432Node\\Microsoft\\.NETFramework\\v4.0.30319' do
  target_key 'SchUseStrongCrypto'
  source_key_path 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\.NETFramework\\v4.0.30319'
  source_key 'SchUseStrongCrypto'
end
