source "https://rubygems.org"

group :development do
  # The current official branch is the 'windows-guest-support' branch, but it isn't working for me right now.
  # gem "test-kitchen", :git => 'https://github.com/test-kitchen/test-kitchen.git', :branch => 'windows-guest-support'
  gem 'test-kitchen', git: 'https://github.com/jdmundrawala/test-kitchen.git', :branch => 'Transport'

  # afiune/Transport supports copying files from Windows -> Windows
  # gem 'kitchen-vagrant', git: 'https://github.com/jdmundrawala/kitchen-vagrant.git', :branch => 'Transport'
  gem 'kitchen-vagrant', git: 'https://github.com/btm/kitchen-vagrant.git', :branch => 'afiune/Transport'

  gem "berkshelf"

  # Adds windows support to vagrant-wrapper gem
  gem "vagrant-wrapper", git: 'https://github.com/btm/gem-vagrant-wrapper.git', :branch => 'windows'

  # We should be able to remove those once vagrant 1.7.0+ is fixed (https://github.com/mitchellh/vagrant/issues/4924)
  #      vagrant (= 1.6.5) x86-mingw32 depends on
  #      bundler (< 1.7.0, >= 1.5.2) x86-mingw32
  gem "bundler", "< 1.7.0"
end
