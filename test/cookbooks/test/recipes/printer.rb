# Add Drivers to test  printer_driver resource
windows_printer_driver 'HP Color LaserJet 1600 Class Driver' do
  action :install
end

windows_printer_driver 'Dell 1130 Laser Printer' do
  action :install
end

# Remove driver to test printer_driver resource
windows_printer_driver 'Dell 1130 Laser Printer' do
  action :delete
end

# Add printer to test printer resource
windows_printer 'HP Color LaserJet 1600' do
  driver_name 'HP Color LaserJet 1600 Class Driver'
  ipv4_address '192.168.100.100'
end