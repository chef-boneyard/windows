windows_user_privilege 'vagrant' do
  privilege %w(SeBatchLogonRight SeServiceLogonRight)
  action :add
end
