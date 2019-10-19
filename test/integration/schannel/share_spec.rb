describe powershell('[Net.ServicePointManager]::SecurityProtocol') do
  its('strip') { should match /Tls12/ }
end
