describe registry_key('HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') do
  its('wordpad') { should eq '"C:\\Windows\\System32\\write.exe"' }
end

describe registry_key('HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\notepad') do
  it { should_not exist }
end
