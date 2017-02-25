windows_pagefile 'create the pagefile' do
  name 'C:\pagefile.sys'
  initial_size 100
  maximum_size 200
end

windows_pagefile 'delete the pagefile' do
  name 'C:\pagefile.sys'
  action :delete
end
