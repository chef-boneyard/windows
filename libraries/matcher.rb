
### windows_auto_run

def create_windows_auto_run( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_auto_run, :create, message )
end

def remove_windows_auto_run( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_auto_run, :remove, message )
end


### windows_batch

def run_windows_batch( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_batch, :run, message )
end


### windows_feature

def install_windows_feature( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_feature, :install, message )
end

def remove_windows_feature( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_feature, :remove, message )
end


### windows_package

def install_windows_package( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_package, :install, message )
end

def remove_windows_package( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_package, :remove, message )
end


### windows_pagefile

def set_windows_pagefile( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_pagefile, :set, message )
end

def delete_windows_pagefile( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_pagefile, :delete, message )
end


### windows_path

def add_windows_path( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_path, :add, message )
end

def remove_windows_path( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_path, :remove, message )
end


### windows_printer

def create_windows_printer( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_printer, :create, message )
end

def delete_windows_printer( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_printer, :delete, message )
end


### windows_printer_port

def create_windows_printer_port( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_printer_port, :create, message )
end

def delete_windows_printer_port( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_printer_port, :delete, message )
end


### windows_reboot

def request_windows_reboot( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_reboot, :request, message )
end

def cancel_windows_reboot( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_reboot, :cancel, message )
end


### windows_registry

def create_windows_registry( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_registry, :create, message )
end

def modify_windows_registry( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_registry, :modify, message )
end

def force_modify_windows_registry( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_registry, :force_modify, message )
end

def remove_windows_registry( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_registry, :remove, message )
end


### windows_shortcut

def create_windows_shortcut( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_shortcut, :create, message )
end


### windows_task

def create_windows_task( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_task, :create, message )
end

def delete_windows_task( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_task, :delete, message )
end

def run_windows_task( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_task, :run, message )
end

def change_windows_task( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_task, :change, message )
end


### windows_zipfile

def unzip_windows_zipfile( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_zipfile, :unzip, message )
end

def zip_windows_zipfile( message )
  ChefSpec::Matchers::ResourceMatcher.new( :windows_zipfile, :zip, message )
end

