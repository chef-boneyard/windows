adv_audit_policy 'Set Account Logon\\Audit Credential Validation audit policy to "Success and Failure"' do
  subcategory 'Credential Validation'
  policy_state 'success and failure'
end

adv_audit_policy 'Set Account Logon\\Audit Kerberos Authentication Service audit policy to "Succes"' do
  subcategory 'Kerberos Authentication Service'
  policy_state 'success'
end

adv_audit_policy 'Set Account Logon\\Audit Kerberos Service Ticket Operations audit policy to "Failure"' do
  subcategory 'Kerberos Service Ticket Operations'
  policy_state 'failure'
end

adv_audit_policy 'Set Account Logon\\Audit Other Account Logon Events audit policy to "No Auditing"' do
  subcategory 'Other Account Logon Events'
  policy_state 'no auditing'
end
