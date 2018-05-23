# Windows Cookbook

[![Build status](https://ci.appveyor.com/api/projects/status/9x4uepmm1g4rktie/branch/master?svg=true)](https://ci.appveyor.com/project/ChefWindowsCookbooks/windows/branch/master) [![Cookbook Version](https://img.shields.io/cookbook/v/windows.svg)](https://supermarket.chef.io/cookbooks/windows)

Provides a set of Windows-specific resources to aid in the creation of cookbooks/recipes targeting the Windows platform.

## Requirements

### Platforms

- Windows 7
- Windows Server 2008 R2
- Windows 8, 8.1
- Windows Server 2012 (R1, R2)

### Chef

- Chef 12.6+

## Resources

### windows_auto_run

#### Actions

- `:create` - Create an item to be run at login
- `:remove` - Remove an item that was previously setup to run at login

#### Properties

- `name` - Name attribute. The name of the value to be stored in the registry
- `program` - The program to be run at login
- `args` - The arguments for the program

#### Examples

Run BGInfo at login

```ruby
windows_auto_run 'BGINFO' do
  program 'C:/Sysinternals/bginfo.exe'
  args    '\'C:/Sysinternals/Config.bgi\' /NOLICPROMPT /TIMER:0'
  action  :create
end
```

### windows_certificate

Installs a certificate into the Windows certificate store from a file, and grants read-only access to the private key for designated accounts. Due to current limitations in WinRM, installing certificated remotely may not work if the operation requires a user profile. Operations on the local machine store should still work.

#### Actions

- `:create` - creates or updates a certificate.
- `:delete` - deletes a certificate.
- `:acl_add` - adds read-only entries to a certificate's private key ACL.

#### Properties

- `source` - name attribute. The source file (for create and acl_add), thumbprint (for delete and acl_add) or subject (for delete).
- `pfx_password` - the password to access the source if it is a pfx file.
- `private_key_acl` - array of 'domain\account' entries to be granted read-only access to the certificate's private key. This is not idempotent.
- `store_name` - the certificate store to manipulate. One of MY (default : personal store), CA (trusted intermediate store) or ROOT (trusted root store).
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
- `address` - the address to bind against. Default is 0.0.0.0 (all IP addresses).
- `port` - the port to bind against. Default is 443.
- `app_id` - the GUID that defines the application that owns the binding. Default is the values used by IIS.
- `store_name` - the store to locate the certificate in. One of MY (default : personal store), CA (trusted intermediate store) or ROOT (trusted root store).

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

### windows_feature

**BREAKING CHANGE - Version 3.0.0**

This resource has been moved from using LWRPs and multiple providers to using Custom Resources. To maintain functionality, you'll need to change `provider` to `install_method`.

Windows Roles and Features can be thought of as built-in operating system packages that ship with the OS. A server role is a set of software programs that, when they are installed and properly configured, lets a computer perform a specific function for multiple users or other computers within a network. A Role can have multiple Role Services that provide functionality to the Role. Role services are software programs that provide the functionality of a role. Features are software programs that, although they are not directly parts of roles, can support or augment the functionality of one or more roles, or improve the functionality of the server, regardless of which roles are installed. Collectively we refer to all of these attributes as 'features'.

This resource allows you to manage these 'features' in an unattended, idempotent way.

There are three methods for the `windows_feature` which map into Microsoft's three major tools for managing roles/features: [Deployment Image Servicing and Management (DISM)](http://msdn.microsoft.com/en-us/library/dd371719%28v=vs.85%29.aspx), [Servermanagercmd](http://technet.microsoft.com/en-us/library/ee344834%28WS.10%29.aspx) (The CLI for Server Manager), and [PowerShell](https://technet.microsoft.com/en-us/library/cc731774(v=ws.11).aspx). As Servermanagercmd is deprecated, Chef will set the default method to `:windows_feature_dism` if `dism.exe` is present on the system being configured. The default method will fall back to `:windows_feature_servermanagercmd`, and then `:windows_feature_powershell`.

For more information on Roles, Role Services and Features see the [Microsoft TechNet article on the topic](http://technet.microsoft.com/en-us/library/cc754923.aspx). For a complete list of all features that are available on a node type either of the following commands at a command prompt:

For Dism:

```text
dism /online /Get-Features
```

For ServerManagerCmd:

```text
servermanagercmd -query
```

For PowerShell:

```text
get-windowsfeature
```

#### Actions

- `:install` - install a Windows role/feature
- `:remove` - remove a Windows role/feature
- `:delete` - remove a Windows role/feature from the image (not supported by ServerManagerCmd)

#### Properties

- `feature_name` - name of the feature/role(s) to install. The same feature may have different names depending on the provider used (ie DHCPServer vs DHCP; DNS-Server-Full-Role vs DNS).
- `all` - Boolean. Optional. Default: false. DISM and Powershell providers only. Forces all dependencies to be installed.
- `source` - String. Optional. DISM provider only. Uses local repository for feature install.
- `install_method` - Symbol. Optional. **REPLACEMENT FOR THE PREVIOUS PROVIDER OPTION** If not supplied, Chef will determine which method to use (in the order of `:windows_feature_dism`, `:windows_feature_servercmd`, `:windows_feature_powershell`)

#### Examples

Install the DHCP Server feature

```ruby
windows_feature 'DHCPServer' do
  action :install
end
```

Install the .Net 3.5.1 feature on Server 2012 using repository files on DVD and install all dependencies

```ruby
windows_feature "NetFx3" do
  action :install
  all true
  source "d:\sources\sxs"
end
```

Remove Telnet Server and Client features

```ruby
windows_feature ['TelnetServer', 'TelnetClient'] do
  action :remove
end
```

Add the SMTP Server feature using the PowerShell provider

```ruby
windows_feature "smtp-server" do
  action :install
  all true
  install_method :windows_feature_powershell
end
```

Install multiple features using one resource with the PowerShell provider

```ruby
windows_feature ['Web-Asp-Net45', 'Web-Net-Ext45'] do
  action :install
  install_method :windows_feature_powershell
end
```

### windows_font

Installs a font.

Font files should be included in the cookbooks

#### Actions

- `:install` - install a font to the system fonts directory.

#### Properties

- `name` - The file name of the font file name to install. The path defaults to the files/default directory of the cookbook you're calling windows_font from. Defaults to the resource name.
- `source` - Set an alternate path to the font file.

#### Examples

```ruby
windows_font 'Code New Roman.otf'
```

### windows_http_acl

Sets the Access Control List for an http URL to grant non-admin accounts permission to open HTTP endpoints.

#### Actions

- `:create` - creates or updates the ACL for a URL.
- `:delete` - deletes the ACL from a URL.

#### Properties

- `url` - the name of the url to be created/deleted.
- `sddl` - the DACL string configuring all permissions to URL. Mandatory for create if user is not provided. Can't be use with `user`.
- `user` - the name (domain\user) of the user or group to be granted permission to the URL. Mandatory for create if sddl is not provided. Can't be use with `sddl`. Only one user or group can be granted permission so this replaces any previously defined entry.

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

### windows_pagefile

Configures the file that provides virtual memory for applications requiring more memory than available RAM or that are paged out to free up memory in use.


#### Actions

- `:set` - configures the default pagefile, creating if it doesn't exist.
- `:delete` - deletes the specified pagefile.

#### Properties

- `name` - the path to the pagefile,  String, name_property: true
- `system_managed` - configures whether the system manages the pagefile size. [true, false]
- `automatic_managed` - all of the settings are managed by the system. If this is set to true, other settings will be ignored. [true, false], default: false
- `initial_size` - initial size of the pagefile in bytes. Integer
- `maximum_size` - maximum size of the pagefile in bytes. Integer

### windows_printer_driver

Create and delete printer drivers.

#### Actions

- `:install` - Install a printer driver. This is the default action.
- `:delete` - Delete a printer driver.
 
#### Properties 

- `driver_name` - Name attribute. Required. IPv4 address, e.g. '10.0.24.34'
- `inf_path` - Specifies the path of the printer driver INF file in the driver store. Optional. 
- `printerenvironment` - Specifies the printer driver environment. ('Windows NT x86' or 'Windows x64') Optional. 

#### Examples

Install 'HP Color LaserJet 1600 Class Driver' driver.

```ruby
windows_printer_driver 'HP Color LaserJet 1600 Class Driver' do
  action :install
end
```

Delete 'HP Color LaserJet 1600 Class Driver'

```ruby
windows_printer_driver 'Dell 1130 Laser Printer' do
  action :delete
end
```

### windows_printer_port

Create and delete TCP/IPv4 printer ports.

#### Actions

- `:create` - Create a TCIP/IPv4 printer port. This is the default action.
- `:delete` - Delete a TCIP/IPv4 printer port

#### Properties

- `ipv4_address` - Name attribute. Required. IPv4 address, e.g. '10.0.24.34'
- `port_name` - Port name. Optional. Defaults to 'IP_' + `ipv4_address`
- `port_number` - Port number. Optional. Defaults to 9100.
- `port_description` - Port description. Optional.
- `snmp_enabled` - Boolean. Optional. Defaults to false.
- `port_protocol` - Port protocol, 1 (RAW), or 2 (LPR). Optional. Defaults to 1.

#### Examples

Create a TCP/IP printer port named 'IP_10.4.64.37' with all defaults

```ruby
windows_printer_port '10.4.64.37' do
  action :create
end
```

Delete a printer port

```ruby
windows_printer_port '10.4.64.37' do
  action :delete
end
```

Delete a port with a custom port_name

```ruby
windows_printer_port '10.4.64.38' do
  port_name 'My awesome port'
  action :delete
end
```

Create a port with more options

```ruby
windows_printer_port '10.4.64.39' do
  port_name 'My awesome port'
  snmp_enabled true
  port_protocol 2
end
```

### windows_printer

Create Windows printer. Note that this doesn't currently install a printer driver. You must already have the driver installed on the system.

The Windows Printer LWRP will automatically create a TCP/IP printer port for you using the `ipv4_address` property. If you want more granular control over the printer port, just create it using the `windows_printer_port` LWRP before creating the printer.

#### Actions

- `:create` - Create a new printer
- `:delete` - Delete a new printer

#### Properties

- `device_id` - Name attribute. Required. Printer queue name, e.g. 'HP LJ 5200 in fifth floor copy room'
- `comment` - Optional string describing the printer queue.
- `default` - Boolean. Optional. Defaults to false. Note that Windows sets the first printer defined to the default printer regardless of this setting.
- `driver_name` - String. Required. Exact name of printer driver. Note that the printer driver must already be installed on the node.
- `location` - Printer location, e.g. 'Fifth floor copy room', or 'US/NYC/Floor42/Room4207'
- `shared` - Boolean. Defaults to false.
- `share_name` - Printer share name.
- `ipv4_address` - Printer IPv4 address, e.g. '10.4.64.23'. You don't have to be able to ping the IP address to set it. Required.

An error of "Set-WmiInstance : Generic failure" is most likely due to the printer driver name not matching or not being installed.

#### Examples

Create a printer

```ruby
windows_printer 'HP LaserJet 5th Floor' do
  driver_name 'HP LaserJet 4100 Series PCL6'
  ipv4_address '10.4.64.38'
end
```

Delete a printer. Note: this doesn't delete the associated printer port. See `windows_printer_port` above for how to delete the port.

```ruby
windows_printer 'HP LaserJet 5th Floor' do
  action :delete
end
```

### windows_share

Creates, modifies and removes Windows shares. All properties are idempotent.

#### Actions

- :create: creates/modifies a share
- :delete: deletes a share

#### Properties

- share_name: name attribute, the share name.
- path: path to the directory to be shared. Required when creating. If the share already exists on a different path then it is deleted and re-created.
- description: description to be applied to the share
- full_users: array of users which should have "Full control" permissions
- change_users: array of users which should have "Change" permissions
- read_users: array of users which should have "Read" permissions

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

### windows_shortcut

Creates and modifies Windows shortcuts.

#### Actions

- `:create` - create or modify a windows shortcut

#### Properties

- `name` - name attribute. The shortcut to create/modify.
- `target` - what the shortcut links to
- `arguments` - arguments to pass to the target when the shortcut is executed
- `description` - description of the shortcut
- `cwd` - Working directory to use when the target is executed
- `iconlocation` - Icon to use, in the format of `"path, index"` where index is which icon in that file to use (See [WshShortcut.IconLocation](https://msdn.microsoft.com/en-us/library/3s9bx7at.aspx))

#### Examples

Add a shortcut all users desktop:

```ruby
require 'win32ole'
all_users_desktop = WIN32OLE.new("WScript.Shell").SpecialFolders("AllUsersDesktop")

windows_shortcut "#{all_users_desktop}/Notepad.lnk" do
  target "C:\\WINDOWS\\notepad.exe"
  description "Launch Notepad"
  iconlocation "C:\\windows\\notepad.exe, 0"
end
```

#### Library Methods

```ruby
Registry.value_exists?('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','BGINFO')
Registry.key_exists?('HKLM\SOFTWARE\Microsoft')
BgInfo = Registry.get_value('HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','BGINFO')
```

### windows_path

#### Actions

- `:add` - Add an item to the system path
- `:remove` - Remove an item from the system path

#### Properties

- `path` - Name attribute. The name of the value to add to the system path

#### Examples

Add Sysinternals to the system path

```ruby
windows_path 'C:\Sysinternals' do
  action :add
end
```

Remove 7-Zip from the system path

```ruby
windows_path 'C:\7-Zip' do
  action :remove
end
```

### windows_task

Creates, deletes or runs a Windows scheduled task. Requires Windows Server 2008 due to API usage.

#### Actions

- `:create` - creates a task (or updates existing if user or command has changed)
- `:delete` - deletes a task
- `:run` - runs a task
- `:end` - ends a task
- `:change` - changes the un/pw or command of a task
- `:enable` - enable a task
- `:disable` - disable a task

#### Properties

- `task_name` - name attribute, The task name. ("Task Name" or "/Task Name")
- `force` - When used with create, will update the task.
- `command` - The command the task will run.
- `cwd` - The directory the task will be run from.
- `user` - The user to run the task as. (defaults to 'SYSTEM')
- `password` - The user's password. (requires user)
- `run_level` - Run with `:limited` or `:highest` privileges.
- `frequency` - Frequency with which to run the task. (default is :hourly. Other valid values include :minute, :hourly, :daily, :weekly, :monthly, :once, :on_logon, :onstart, :on_idle) :once requires start_time
- `frequency_modifier` - Multiple for frequency. (15 minutes, 2 days). Monthly tasks may also use these values": ('FIRST', 'SECOND', 'THIRD', 'FOURTH', 'LAST', 'LASTDAY')
- `start_day` - Specifies the first date on which the task runs. Optional string (MM/DD/YYYY)
- `start_time` - Specifies the start time to run the task. Optional string (HH:mm)
- `interactive_enabled` - (Allow task to run interactively or non-interactively. Requires user and password.)
- `day` - For monthly or weekly tasks, the day(s) on which the task runs. (MON - SUN, *, 1 - 31)
- `months` - The Months of the year on which the task runs. (JAN, FEB, MAR, APR, MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC, *). Multiple months should be comma delimited.
- `idle_time` - For :on_idle frequency, the time (in minutes) without user activity that must pass to trigger the task. (1 - 999)

#### Examples

Create a `chef-client` task with TaskPath `\` running every 15 minutes

```ruby
windows_task 'chef-client' do
  user 'Administrator'
  password '$ecR3t'
  cwd 'C:\\chef\\bin'
  command 'chef-client -L C:\\tmp\\'
  run_level :highest
  frequency :minute
  frequency_modifier 15
end
```

Update `chef-client` task with new password and log location

```ruby
windows_task 'chef-client' do
  user 'Administrator'
  password 'N3wPassW0Rd'
  cwd 'C:\\chef\\bin'
  command 'chef-client -L C:\\chef\\logs\\'
  action :change
end
```

Delete a task named `old task`

```ruby
windows_task 'old task' do
  action :delete
end
```

Enable a task named `chef-client`

```ruby
windows_task 'chef-client' do
  action :enable
end
```

Disable a task named `ProgramDataUpdater` with TaskPath `\Microsoft\Windows\Application Experience\`

```ruby
windows_task '\Microsoft\Windows\Application Experience\ProgramDataUpdater' do
  action :disable
end
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

## Windows ChefSpec Matchers

The Windows cookbook includes custom [ChefSpec](https://github.com/sethvargo/chefspec) matchers you can use to test your own cookbooks that consume Windows cookbook LWRPs.

### Example Matcher Usage

```ruby
expect(chef_run).to install_windows_package('Node.js').with(
  source: 'http://nodejs.org/dist/v0.10.26/x64/node-v0.10.26-x64.msi')
```

### Windows Cookbook Matchers

- create_windows_auto_run
- remove_windows_auto_run
- create_windows_certificate
- delete_windows_certificate
- add_acl_to_windows_certificate
- create_windows_certificate_binding
- delete_windows_certificate_binding
- install_windows_feature
- install_windows_feature_dism
- install_windows_feature_servermanagercmd
- install_windows_feature_powershell
- remove_windows_feature
- remove_windows_feature_dism
- remove_windows_feature_servermanagercmd
- remove_windows_feature_powershell
- delete_windows_feature
- delete_windows_feature_dism
- delete_windows_feature_powershell
- install_windows_font
- create_windows_http_acl
- delete_windows_http_acl
- install_windows_package
- remove_windows_package
- set_windows_pagefile
- add_windows_path
- remove_windows_path
- create_windows_printer
- delete_windows_printer
- create_windows_printer_port
- delete_windows_printer_port
- create_windows_shortcut
- create_windows_shortcut
- create_windows_task
- disable_windows_task
- enable_windows_task
- delete_windows_task
- run_windows_task
- change_windows_task
- unzip_windows_zipfile_to
- zip_windows_zipfile_to

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
Copyright 2011-2016, Chef Software, Inc.
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
