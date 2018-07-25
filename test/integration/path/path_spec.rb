describe file('c:/paths.txt') do
  it { should exist }
  its('content') { should match(/C:\\path_test_path/) }
  its('content') { should match(/c:\\path_test_with_forward_slashes/) }
  its('content') { should match(/C:\\path_test_another_path/) }
end
