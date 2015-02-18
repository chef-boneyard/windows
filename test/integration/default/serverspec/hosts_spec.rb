require 'spec_helper'

describe 'Host File' do

describe file('c:/chef') do
  it { should be_directory }
end

end
