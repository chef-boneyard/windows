# Windows Cookbook

[![Build status](https://ci.appveyor.com/api/projects/status/9x4uepmm1g4rktie/branch/master?svg=true)](https://ci.appveyor.com/project/ChefWindowsCookbooks/windows/branch/master) [![Cookbook Version](https://img.shields.io/cookbook/v/windows.svg)](https://supermarket.chef.io/cookbooks/windows)

Provides a set of Windows-specific resources to aid in the creation of cookbooks/recipes targeting the Windows platform.

## Requirements

### Platforms

- Windows 7
- Windows Server 2008 R2
- Windows 8, 8.1
- Windows Server 2012 (R1, R2)
- Windows Server 2016

### Chef

- Chef 14+

## Resources

### Deprecated Resources Note

As of Chef 14.7+ the windows_share and windows_certificate resources are now included in the Chef Client. If you are running Chef 14.7+ the resources in Chef client will take precedence over the resources in this cookbook. In November 2019 we will release a new major version of this cookbook that removes these resources.

### windows_certificate

`Note`: This resource is now included in Chef 14.7 and later. There is no need to depend on the Windows cookbook for this resource.

Installs a certificate into the Windows certificate store from a file, and grants read-only access to the private key for designated accounts. Due to current limitations in WinRM, installing certificated remotely may not work if the operation requires a user profile. Operations on the local machine store should still work.

#### Actions

- `:create` - creates or updates a certificate.
- `:delete` - deletes a certificate.
- `:acl_add` - adds read-only entries to a certificate's private key ACL.
- `:verify` - logs whether or not a certificate is valid

#### Properties

- `source` - name attribute. The source file (for create and acl_add), thumbprint (for delete and acl_add) or subject (for delete).
- `pfx_password` - the password to access the source if it is a pfx file.
- `private_key_acl` - array of 'domain\account' entries to be granted read-only access to the certificate's private key. This is not idempotent.
- `store_name` - the certificate store to manipulate. One of:
  - MY (Personal)
  - CA (Intermediate Certification Authorities)
  - ROOT (Trusted Root Certification Authorities)
  - TRUSTEDPUBLISHER (Trusted Publishers)
  - CLIENTAUTHISSUER (Client Authentication Issuers)
  - REMOTE DESKTOP (Remote Desktop)
  - TRUSTEDDEVICES (Trusted Devices)
  - WEBHOSTING (Web Hosting)
  - AUTHROOT (Third-Party Root Certification Authorities)
  - TRUSTEDPEOPLE (Trusted People)
  - SMARTCARDROOT (Smart Card Trusted Roots)
  - TRUST (Enterprise Trust)
  - DISALLOWED (Untrusted Certificates)
- `user_store` - if false (default) then use the local machine store; if true then use the current user's store.

#### Examples

```ruby
# Add PFX cert to local machine personal store and grant accounts read-only access to private key
windows_certificate "c:/test/mycert.pfx" do
    pfx_password    "password"
    private_key_acl    ["acme\fred", "pc\jane"]
end
```

```ruby
# Add cert to trusted intermediate store
windows_certificate "c:/test/mycert.cer" do
    store_name    "CA"
end
```

```ruby
# Remove all certificates matching the subject
windows_certificate "me.acme.com" do
    action :delete
end
```

### windows_certificate_binding

Binds a certificate to an HTTP port in order to enable TLS communication.

#### Actions

- `:create` - creates or updates a binding.
- `:delete` - deletes a binding.

#### Properties

- `cert_name` - name attribute. The thumbprint(hash) or subject that identifies the certificate to be bound.
- `name_kind` - indicates the type of cert_name. One of :subject (default) or :hash.
- `address` - the address to bind against. Default is 0.0.0.0 (all IP addresses). One of:
  - IP v4 address `1.2.3.4`
  - IP v6 address `[::1]`
  - Host name `www.foo.com`
- `port` - the port to bind against. Default is 443.
- `app_id` - the GUID that defines the application that owns the binding. Default is the values used by IIS.
- `store_name` - the store to locate the certificate in. One of:
  - MY (Personal)
  - CA (Intermediate Certification Authorities)
  - ROOT (Trusted Root Certification Authorities)
  - TRUSTEDPUBLISHER (Trusted Publishers)
  - CLIENTAUTHISSUER (Client Authentication Issuers)
  - REMOTE DESKTOP (Remote Desktop)
  - TRUSTEDDEVICES (Trusted Devices)
  - WEBHOSTING (Web Hosting)
  - AUTHROOT (Third-Party Root Certification Authorities)
  - TRUSTEDPEOPLE (Trusted People)
  - SMARTCARDROOT (Smart Card Trusted Roots)
  - TRUST (Enterprise Trust)

#### Examples

```ruby
# Bind the first certificate matching the subject to the default TLS port
windows_certificate_binding "me.acme.com" do
end
```

```ruby
# Bind a cert from the CA store with the given hash to port 4334
windows_certificate_binding "me.acme.com" do
    cert_name    "d234567890a23f567c901e345bc8901d34567890"
    name_kind    :hash
    store_name    "CA"
    port        4334
end
```

### windows_dns

Configures A and CNAME records in Windows DNS. This requires the DNSCMD to be installed, which is done by adding the DNS role to the server or installing the Remote Server Admin Tools.

#### Actions

- :create: creates/updates the DNS entry
- :delete: deletes the DNS entry

#### Properties

- host_name: name attribute. FQDN of the entry to act on.
- dns_server: the DNS server to update. Default is local machine (.)
- record_type: the type of record to create. One of A (default) or CNAME
- target: for A records an array of IP addresses to associate with the host; for CNAME records the FQDN of the host to alias
- ttl: if > 0 then set the time to live of the record

#### Examples

```ruby
# Create A record linked to 2 addresses with a 10 minute ttl
windows_dns "m1.chef.test" do
    target         ['10.9.8.7', '1.2.3.4']
    ttl            600
end
```

```ruby
# Delete records. target is mandatory although not used
windows_dns "m1.chef.test" do
    action    :delete
    target    []
end
```

```ruby
# Set an alias against the node in a role
nodes = search( :node, "role:my_service" )
windows_dns "myservice.chef.test" do
    record_type    'CNAME'
    target        nodes[0]['fqdn']
end
```

### windows_http_acl

Sets the Access Control List for an http URL to grant non-admin accounts permission to open HTTP endpoints.

#### Actions

- `:create` - creates or updates the ACL for a URL.
- `:delete` - deletes the ACL from a URL.

#### Properties

- `url` - the name of the url to be created/deleted.
- `sddl` - the DACL string configuring all permissions to URL. Mandatory for create if user is not provided. Can't be use with `user`.
- `user` - the name (domain\user) of the user or group to be granted permission to the URL. Mandatory for create if sddl is not provided. Can't be use with `sddl`. Only one user or group can be granted permission so this replaces any previously defined entry. If you receive a parameter error your user may not exist.

#### Examples

```ruby
windows_http_acl 'http://+:50051/' do
    user 'pc\\fred'
end
```

```ruby
# Grant access to users "NT SERVICE\WinRM" and "NT SERVICE\Wecsvc" via sddl
windows_http_acl 'http://+:5985/' do
  sddl 'D:(A;;GX;;;S-1-5-80-569256582-2953403351-2909559716-1301513147-412116970)(A;;GX;;;S-1-5-80-4059739203-877974739-1245631912-527174227-2996563517)'
end
```

```ruby
windows_http_acl 'http://+:50051/' do
    action :delete
end
```

### windows_share

`Note`: This resource is now included in Chef 14.7 and later. There is no need to depend on the Windows cookbook for this resource.

Creates, modifies and removes Windows shares. All properties are idempotent.

`Note`: This resource uses PowerShell cmdlets introduced in Windows 2012/8.

#### Actions

- `:create`: creates/modifies a share
- `:delete`: deletes a share

#### Properties

property                 | type       | default       | description
------------------------ | ---------- | ------------- | -----------------------------------------------------------------------------------------------------------------------------------------------------------
`share_name`             | String     | resource name | the share to assign to the share
`path`                   | String     |               | The path of the location of the folder to share. Required when creating. If the share already exists on a different path then it is deleted and re-created.
`description`            | String     |               | description to be applied to the share
`full_users`             | Array      | []            | users which should have "Full control" permissions
`change_users`           | Array      | []            | Users are granted modify permission to access the share.
`read_users`             | Array      | []            | users which should have "Read" permissions
`temporary`              | True/False | false         | The lifetime of the new SMB share. A temporary share does not persist beyond the next restart of the computer
`scope_name`             | String     | '*'           | The scope name of the share.
`ca_timeout`             | Integer    | 0             | The continuous availability time-out for the share.
`continuously_available` | True/False | false         | Indicates that the share is continuously available.
`concurrent_user_limit`  | Integer    | 0 (unlimited) | The maximum number of concurrently connected users the share can accommodate
`encrypt_data`           | True/False | false         | Indicates that the share is encrypted.

#### Examples

```ruby
windows_share "foo" do
  action :create
  path "C:\\foo"
  full_users ["DOMAIN_A\\some_user", "DOMAIN_B\\some_other_user"]
  read_users ["DOMAIN_C\\Domain users"]
end
```

```ruby
windows_share "foo" do
  action :delete
end
```

### windows_user_privilege

Adds the `principal` (User/Group) to the specified privileges (such as `Logon as a batch job` or `Logon as a Service`).

#### Actions

- `:add` - add the specified privileges to the `principal`
- `:remove` - remove the specified privilege of the `principal`

#### Properties

- `principal` - Name attribute, Required, String. The user or group to be granted privileges.
- `privilege` - Required, String/Array. The privilege(s) to be granted.

#### Examples

Grant the Administrator user the `Logon as a batch job` and `Logon as a service` privilege.

```ruby
windows_user_privilege 'Administrator' do
  privilege %w(SeBatchLogonRight SeServiceLogonRight)
end
```

Remove `Logon as a batch job` privilege of Administrator.

```ruby
windows_user_privilege 'Administrator' do
  privilege %w(SeBatchLogonRight)
  action :remove
end
```

#### Available Privileges

```
SeTrustedCredManAccessPrivilege      Access Credential Manager as a trusted caller
SeNetworkLogonRight                  Access this computer from the network
SeTcbPrivilege                       Act as part of the operating system
SeMachineAccountPrivilege            Add workstations to domain
SeIncreaseQuotaPrivilege             Adjust memory quotas for a process
SeInteractiveLogonRight              Allow log on locally
SeRemoteInteractiveLogonRight        Allow log on through Remote Desktop Services
SeBackupPrivilege                    Back up files and directories
SeChangeNotifyPrivilege              Bypass traverse checking
SeSystemtimePrivilege                Change the system time
SeTimeZonePrivilege                  Change the time zone
SeCreatePagefilePrivilege            Create a pagefile
SeCreateTokenPrivilege               Create a token object
SeCreateGlobalPrivilege              Create global objects
SeCreatePermanentPrivilege           Create permanent shared objects
SeCreateSymbolicLinkPrivilege        Create symbolic links
SeDebugPrivilege                     Debug programs
SeDenyNetworkLogonRight              Deny access this computer from the network
SeDenyBatchLogonRight                Deny log on as a batch job
SeDenyServiceLogonRight              Deny log on as a service
SeDenyInteractiveLogonRight          Deny log on locally
SeDenyRemoteInteractiveLogonRight    Deny log on through Remote Desktop Services
SeEnableDelegationPrivilege          Enable computer and user accounts to be trusted for delegation
SeRemoteShutdownPrivilege            Force shutdown from a remote system
SeAuditPrivilege                     Generate security audits
SeImpersonatePrivilege               Impersonate a client after authentication
SeIncreaseWorkingSetPrivilege        Increase a process working set
SeIncreaseBasePriorityPrivilege      Increase scheduling priority
SeLoadDriverPrivilege                Load and unload device drivers
SeLockMemoryPrivilege                Lock pages in memory
SeBatchLogonRight                    Log on as a batch job
SeServiceLogonRight                  Log on as a service
SeSecurityPrivilege                  Manage auditing and security log
SeRelabelPrivilege                   Modify an object label
SeSystemEnvironmentPrivilege         Modify firmware environment values
SeManageVolumePrivilege              Perform volume maintenance tasks
SeProfileSingleProcessPrivilege      Profile single process
SeSystemProfilePrivilege             Profile system performance
SeUnsolicitedInputPrivilege          "Read unsolicited input from a terminal device"
SeUndockPrivilege                    Remove computer from docking station
SeAssignPrimaryTokenPrivilege        Replace a process level token
SeRestorePrivilege                   Restore files and directories
SeShutdownPrivilege                  Shut down the system
SeSyncAgentPrivilege                 Synchronize directory service data
SeTakeOwnershipPrivilege             Take ownership of files or other objects
```

### windows_zipfile

Most version of Windows do not ship with native cli utility for managing compressed files. This resource provides a pure-ruby implementation for managing zip files. Be sure to use the `not_if` or `only_if` meta parameters to guard the resource for idempotence or action will be taken every Chef run.

#### Actions

- `:unzip` - unzip a compressed file
- `:zip` - zip a directory (recursively)

#### Properties

- `path` - name attribute. The path where files will be (un)zipped to.
- `source` - source of the zip file (either a URI or local path) for :unzip, or directory to be zipped for :zip.
- `overwrite` - force an overwrite of the files if they already exist.
- `checksum` - for :unzip, useful if source is remote, if the local file matches the SHA-256 checksum, Chef will not download it.

#### Examples

Unzip a remote zip file locally

```ruby
windows_zipfile 'c:/bin' do
  source 'http://download.sysinternals.com/Files/SysinternalsSuite.zip'
  action :unzip
  not_if {::File.exists?('c:/bin/PsExec.exe')}
end
```

Unzip a local zipfile

```ruby
windows_zipfile 'c:/the_codez' do
  source 'c:/foo/baz/the_codez.zip'
  action :unzip
end
```

Create a local zipfile

```ruby
windows_zipfile 'c:/foo/baz/the_codez.zip' do
  source 'c:/the_codez'
  action :zip
end
```

## Libraries

### WindowsHelper

Helper that allows you to use helpful functions in windows

#### installed_packages

Returns a hash of all DisplayNames installed

```ruby
# usage in a recipe
::Chef::Recipe.send(:include, Windows::Helper)
hash_of_installed_packages = installed_packages
```

#### is_package_installed?

- `package_name` - The name of the package you want to query to see if it is installed
- `returns` - true if the package is installed, false if it the package is not installed

Download a file if a package isn't installed

```ruby
# usage in a recipe to not download a file if package is already installed
::Chef::Recipe.send(:include, Windows::Helper)
is_win_sdk_installed = is_package_installed?('Windows Software Development Kit')

remote_file 'C:\windows\temp\windows_sdk.zip' do
  source 'http://url_to_download/windows_sdk.zip'
  action :create_if_missing
  not_if {is_win_sdk_installed}
end
```

Do something if a package is installed

```ruby
# usage in a provider
include Windows::Helper
if is_package_installed?('Windows Software Development Kit')
  # do something if package is installed
end
```

### Windows::VersionHelper

Helper that allows you to get information of the windows version running on your node. It leverages windows ohai from kernel.os_info, easy to mock and to use even on linux.

#### core_version?

Determines whether given node is running on a windows Core.

```ruby
if ::Windows::VersionHelper.core_version? node
  fail 'Windows Core is not supported'
end
```

#### workstation_version?

Determines whether given node is a windows workstation version (XP, Vista, 7, 8, 8.1, 10)

```ruby
if ::Windows::VersionHelper.workstation_version? node
  fail 'Only server version of windows are supported'
end
```

#### server_version?

Determines whether given node is a windows server version (Server 2003, Server 2008, Server 2012, Server 2016)

```ruby
if ::Windows::VersionHelper.server_version? node
  puts 'Server version of windows are cool'
end
```

#### nt_version

Determines NT version of the given node

```ruby
case ::Windows::VersionHelper.nt_version node
  when '6.0' then 'Windows vista or Server 2008'
  when '6.1' then 'Windows 7 or Server 2008R2'
  when '6.2' then 'Windows 8 or Server 2012'
  when '6.3' then 'Windows 8.1 or Server 2012R2'
  when '10.0' then 'Windows 10'
end
```

## Usage

Place an explicit dependency on this cookbook (using depends in the cookbook's metadata.rb) from any cookbook where you would like to use the Windows-specific resources/providers that ship with this cookbook.

```ruby
depends 'windows'
```

## License & Authors

- Author:: Seth Chisamore ([schisamo@chef.io](mailto:schisamo@chef.io))
- Author:: Doug MacEachern ([dougm@vmware.com](mailto:dougm@vmware.com))
- Author:: Paul Morton ([pmorton@biaprotect.com](mailto:pmorton@biaprotect.com))
- Author:: Doug Ireton ([doug.ireton@nordstrom.com](mailto:doug.ireton@nordstrom.com))

```text
Copyright 2011-2018, Chef Software, Inc.
Copyright 2010, VMware, Inc.
Copyright 2011, Business Intelligence Associates, Inc
Copyright 2012, Nordstrom, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
