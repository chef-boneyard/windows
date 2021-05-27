describe audit_policy do
  its('Credential Validation') { should eq 'Success and Failure' }
end

describe audit_policy do
  its('Kerberos Authentication Service') { should eq 'Success' }
end

describe audit_policy do
  its('Kerberos Service Ticket Operations') { should eq 'Failure' }
end

describe audit_policy do
  its('Other Account Logon Events') { should eq 'No Auditing' }
end