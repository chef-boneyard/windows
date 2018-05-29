#
# Author:: Jared Kauppila (<jared@kauppi.la>)
# Cookbook:: windows
# Resource:: user_privilege
#

property :principal, String, name_property: true
property :privilege, [Array, String], required: true, coerce: proc { |v| [*v].sort }

action :add do
  ([*new_resource.privilege] - [*current_resource.privilege]).each do |user_right|
    converge_by("adding user privilege #{user_right}") do
      Chef::ReservedNames::Win32::Security.add_account_right(new_resource.principal, user_right)
    end
  end
end

# Remove cannot be implemented until https://github.com/chef/chef/issues/6716

load_current_value do |desired|
  privilege Chef::ReservedNames::Win32::Security.get_account_right(desired.principal)
end
