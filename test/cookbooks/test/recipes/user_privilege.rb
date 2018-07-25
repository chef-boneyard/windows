# Adding 5 Privileges
windows_user_privilege 'vagrant' do
  privilege %w(SeIncreaseQuotaPrivilege SeServiceLogonRight SeTimeZonePrivilege SeCreateTokenPrivilege SeBackupPrivilege)
  action :add
end

# Removing 3 of them
windows_user_privilege 'vagrant' do
  privilege %w(SeIncreaseQuotaPrivilege SeServiceLogonRight SeTimeZonePrivilege)
  action :remove
end

# Removing 1 from already removed
windows_user_privilege 'vagrant' do
  privilege %w(SeIncreaseQuotaPrivilege)
  action :remove
end

# Removing few present & few already removed
windows_user_privilege 'vagrant' do
  privilege %w(SeServiceLogonRight SeTimeZonePrivilege SeCreateTokenPrivilege SeBackupPrivilege)
  action :remove
end
