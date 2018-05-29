describe command('net share') do
  its('exit_status') { should eq 0 }
  its('stdout') { should_not match /^no share/ }
  its('stdout') { should match /^change\s*C:\/test_share*/ }
  its('stdout') { should match /^changed_dir\s*C:\/test_share*/ }
  its('stdout') { should match /^read_only\s*C:\/test_share*/ }
  its('stdout') { should match /^full\s*C:\/test_share*/ }
end
