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
end
