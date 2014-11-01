# This recipe makes sure that updating that path does not trash it
# Failing to converge this recipe means that windows_path trashed
#
windows_path 'C:\path_test_path' do
  action :add
end

powershell_script 'foo' do
  code 'echo hello'
end
