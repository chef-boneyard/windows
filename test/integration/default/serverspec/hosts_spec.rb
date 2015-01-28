require 'spec_helper'

describe 'Host File' do

  describe file('c:/windows/system32/drivers/etc/hosts') do
  it { should be_file }
end

end