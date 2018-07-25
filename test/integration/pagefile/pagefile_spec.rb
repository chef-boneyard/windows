describe file('C:\pagefile.sys') do
  it { should exist }
end

describe command('wmic pagefileset') do
  its('exit_status') { should eq 0 } # if it was system managed it would be 1
  its('stderr') { should_not match /No Instance\(s\) Available/ } # not system managed
end
