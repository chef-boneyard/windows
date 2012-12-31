action :create do
  if @current_resource.exists
    Chef::Log.info "#{ @new_resource } already exists - nothing to do."
  else
    create_printer
  end
end

action :delete do
  if @current_resource.exists
    delete_printer
  else
    Chef::Log.info "#{ @current_resource } doesn't exist - can't delete."
  end
end

def load_current_resource
  @current_resource = Chef::Resource::WindowsPrinter.new(@new_resource.name)
  @current_resource.name(@new_resource.name)

  if printer_exists?(@current_resource.name)
    # TODO: Set @current_resource printer properties from registry
    @current_resource.exists = true
  end
end


private

PRINTERS_REG_KEY = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Printers\\'

def printer_exists?(name)
  printer_reg_key = PRINTERS_REG_KEY + name
  Chef::Log.debug "Checking to see if this reg key exists: '#{ printer_reg_key }'"
  Registry.key_exists?(printer_reg_key)
end

def create_printer
  # Create the printer port first
  windows_printer_port @new_resource.ipv4_address do
  end

  port_name = @new_resource.port_name || "IP_#{ @new_resource.ipv4_address }"

  powershell "Creating printer: #{ new_resource.name }" do
    code <<-EOH

      Set-WmiInstance -class Win32_Printer `
        -EnableAllPrivileges `
        -Argument @{ DeviceID   = "#{ new_resource.device_id }";
                     Comment    = "#{ new_resource.comment }";
                     Default    = "$#{ new_resource.default }";
                     DriverName = "#{ new_resource.driver_name }";
                     Location   = "#{ new_resource.location }";
                     PortName   = "#{ port_name }";
                     Shared     = "$#{ new_resource.shared }";
                     ShareName  = "#{ new_resource.share_name }";
                  }
    EOH
  end

  @new_resource.updated_by_last_action(true)
end

def delete_printer
  powershell "Deleting printer: #{ new_resource.name }" do
    code <<-EOH
      $printer = Get-WMIObject -class Win32_Printer -EnableAllPrivileges -Filter "name = '#{ new_resource.name }'"
      $printer.Delete()
    EOH
  end

  @new_resource.updated_by_last_action(true)
end
