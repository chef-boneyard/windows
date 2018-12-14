def thumbprint_script(thumbprint:, location: 'My', store: 'LocalMachine') 
  "if (gci Cert:\\#{store}\\#{location}\ -Recurse | where-object { $_.Thumbprint -eq '#{thumbprint}' }) {$true} else {$false}"
end

def private_key_script(thumbprint:, location: 'My', store: 'LocalMachine') 
  "(gci Cert:\\#{store}\\#{location}\ -Recurse | where-object { $_.Thumbprint -eq '#{thumbprint}' })[0].HasPrivateKey"
end

# delete certificate by thumbprint from MY certificate store
describe powershell(thumbprint_script(thumbprint: '323C118E1BF7B8B65254E2E2100DD6029037F096')) do
  its('strip') { should eq 'False' }
end

# delete certificate by thumbprint from MY certificate store (DER format)
describe powershell(thumbprint_script(thumbprint: 'b1bc968bd4f49d622aa89a81f2150152a41d829c')) do
  its('strip') { should eq 'False' }
end

# Add (.CER) DER encoded binary X.509 certificate in MY certificate store
describe powershell(thumbprint_script(thumbprint: '47beabc922eae80e78783462a79f45c254fde68b')) do
  its('strip') { should eq 'True' }
end

# Add (.CER) Base64 encoded X.509 certificate in ROOT certificate store
describe powershell(thumbprint_script(thumbprint: '2796bae63f1801e277261ba0d77770028f20eee4', location: 'CA')) do
  its('strip') { should eq 'True' }
end

# Delete (.CRT) format certificate in MY certificate store
describe powershell(thumbprint_script(thumbprint: '28e96cdb1dba273fd1a6151be15f088f26046273')) do
  its('strip') { should eq 'False' }
end

# Delete (.PFX) format certificate with password in CA certificate store
describe powershell(thumbprint_script(thumbprint: '5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6', location: 'CA')) do
  its('strip') { should eq 'False' }
end

# delete certificate by thumbprint from MY certificate store
describe powershell(thumbprint_script(thumbprint: 'b1bc968bd4f49d622aa89a81f2150152a41d829c', location: 'CA')) do
  its('strip') { should eq 'False' }
end

# Install PFX certificate with private key in MY store
describe powershell(private_key_script(thumbprint: '5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6')) do
  its('strip') { should eq 'True' }
end

# Add (.CRT) format certificate for validation tests exists
describe powershell(thumbprint_script(thumbprint: '9E848F52575C6B1A69D6AB62E0288BFAD4A5564E')) do
  its('strip') { should eq 'True' }
end

# delete certificate that is not installed
describe powershell(thumbprint_script(thumbprint: '50AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')) do
  its('strip') { should eq 'False' }
end
