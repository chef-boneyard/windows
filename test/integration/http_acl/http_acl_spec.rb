describe command('netsh http show urlacl url=http://google.com:80/') do
  its('exit_status') { should eq 0 }
  its('stdout') { should_not match /^space user/ }
end
