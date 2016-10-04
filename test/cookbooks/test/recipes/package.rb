include_recipe 'windows::default'

windows_package 'Mercurial 3.6.1 (64-bit)' do
  source 'https://www.mercurial-scm.org/release/windows/Mercurial-3.6.1-x64.exe'
  action :install
end
