share_name = 'prodshare'
dfs_namespace_name = share_name
description = 'My Description'
dfs_folder_path = 'Data\\chef\\target'

describe powershell('(Get-WindowsFeature FS-DFS-Namespace).Installed') do
  its('stdout') { should match(/True/) }
end

describe powershell('(Get-WindowsFeature RSAT-DFS-Mgmt-Con).Installed') do
  its('stdout') { should match(/True/) }
end

describe powershell('(Get-WindowsFeature RSAT-File-Services).Installed') do
  its('stdout') { should match(/True/) }
end

describe directory "C:\\DFSRoots\\#{share_name}" do
  it { should be_directory }
end

describe powershell('get-smbshare') do
  its('stdout') { should match share_name }
end

describe powershell("(Get-DfsnRoot -Path \"\\\\$ENV:COMPUTERNAME\\#{dfs_namespace_name}\")") do
  its('stdout') { should match dfs_namespace_name }
  its('stdout') { should match description }
end

describe powershell("Get-DfsnFolder -Path \"\\\\$ENV:COMPUTERNAME\\#{dfs_namespace_name}\\#{dfs_folder_path}\"") do
  its('stdout') { should match 'Online' }
  its('stdout') { should match(dfs_namespace_name) }
end
