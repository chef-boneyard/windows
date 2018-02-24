windows_pagefile 'have the system manage pagefiles' do
  automatic_managed true
end

windows_pagefile 'delete the pagefile' do
  path 'C:\pagefile.sys'
  action :delete
end

windows_pagefile 'create the pagefile' do
  path 'C:\pagefile.sys'
  initial_size 100
  maximum_size 200
end
