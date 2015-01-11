require 'spec_helper'

describe 'windows::default' do
  context '2012R2' do
    version = '2012R2'
    let(:chef_run) do
      runner = ChefSpec::Runner.new(platform: 'windows', version: version)
      runner.converge(described_recipe)
    end

    gems=%w(win32-api win32-service windows-api windows-pr win32-dir win32-event win32-mutex)
    gems.each() do |gem|
      it "should install gems #{gems}" do
        expect(chef_run).to install_chef_gem(gem)
      end
    end
  end

  context '2008R2' do
    version = '2008R2'
    let(:chef_run) do
      runner = ChefSpec::Runner.new(platform: 'windows', version: version)
      runner.converge(described_recipe)
    end

    gems=%w(win32-api win32-service windows-api windows-pr win32-dir win32-event win32-mutex)
    gems.each() do |gem|
      it "should install gems #{gems}" do
        expect(chef_run).to install_chef_gem(gem)
      end
    end
  end

end

