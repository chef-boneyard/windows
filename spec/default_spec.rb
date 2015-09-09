require_relative 'spec_helper'

describe 'windows::default' do
  let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

  %w( win32-api win32-service ).each do |win_gem|
    it "installes precompiled binary of #{win_gem} gem" do
      expect(chef_run).to install_chef_gem(win_gem).with(options: '--platform=mswin32')
    end
  end

  %w( windows-api windows-pr win32-dir win32-event win32-mutex ).each do |win_gem|
    it "installes #{win_gem} gem" do
      expect(chef_run).to install_chef_gem(win_gem)
    end
  end
end
