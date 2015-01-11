require 'spec_helper'

describe 'windows::default' do
  let(:chef_run) do
    runner = ChefSpec::Runner.new(platform: 'windows', version: '2012R2')
    runner.converge(described_recipe)
  end

  gems=%w(win32-api win32-service windows-api windows-pr win32-dir win32-event win32-mutex)
  gems.each() do |gem|
  it 'should include the community windows recipe' do
    expect(chef_run).to install_chef_gem(gem)
  end
    end

end

