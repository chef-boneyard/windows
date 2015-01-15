module Windows
  module InstalledProgramsHelper
    def program_installed?(program_name)
      installed_packages.include?(program_name)
    end

    def installed_packages
      @installed_packages || begin
        installed_packages = {}
        # Computer\HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall
        installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE)) #rescue nil
        # 64-bit registry view
        # Computer\HKEY_LOCAL_MACHINE\Software\Wow6464Node\Microsoft\Windows\CurrentVersion\Uninstall
        installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE, (::Win32::Registry::Constants::KEY_READ | 0x0100))) #rescue nil
        # 32-bit registry view
        # Computer\HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall
        installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_LOCAL_MACHINE, (::Win32::Registry::Constants::KEY_READ | 0x0200))) #rescue nil
        # Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall
        installed_packages.merge!(extract_installed_packages_from_key(::Win32::Registry::HKEY_CURRENT_USER)) #rescue nil
        installed_packages
      end
    end

    private
    def extract_installed_packages_from_key(hkey = ::Win32::Registry::HKEY_LOCAL_MACHINE, desired = ::Win32::Registry::Constants::KEY_READ)
      uninstall_subkey = 'Software\Microsoft\Windows\CurrentVersion\Uninstall'
      packages = {}
      begin
        ::Win32::Registry.open(hkey, uninstall_subkey, desired) do |reg|
          reg.each_key do |key, wtime|
            begin
              k = reg.open(key, desired)
              display_name = k["DisplayName"] rescue nil
              version = k["DisplayVersion"] rescue "NO VERSION"
              uninstall_string = k["UninstallString"] rescue nil
              if display_name
                packages[display_name] = {:name => display_name,
                                          :version => version,
                                          :uninstall_string => uninstall_string}
              end
            rescue ::Win32::Registry::Error
            end
          end
        end
      rescue ::Win32::Registry::Error
      end
      packages
    end
  end
end