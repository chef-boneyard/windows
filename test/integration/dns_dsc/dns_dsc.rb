describe powershell('if (Get-DnsServerZone -Name \'chef.local\'){$true}else{$false}') do
  its('strip') { should eq 'True' }
end

describe powershell('if (Get-DnsServerResourceRecord -ZoneName chef.local -Name arecord){$true}else{$false}') do
  its('strip') { should eq 'True' }
end

describe powershell('if (Get-DnsServerResourceRecord -ZoneName chef.local -Name cnamerecord){$true}else{$false}') do
  its('strip') { should eq 'True' }
end
