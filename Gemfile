source "https://rubygems.org"

group :development do
  # The current official branch is the 'windows-guest-support' branch, but it isn't working for me right now.
  # gem "test-kitchen", :git => 'https://github.com/test-kitchen/test-kitchen.git', :branch => 'windows-guest-support'
  gem 'test-kitchen', git: 'https://github.com/jdmundrawala/test-kitchen.git', :branch => 'Transport'

  # afiune/Transport supports copying files from Windows -> Windows
  # gem 'kitchen-vagrant', git: 'https://github.com/jdmundrawala/kitchen-vagrant.git', :branch => 'Transport'
  gem 'kitchen-vagrant', git: 'https://github.com/afiune/kitchen-vagrant.git', :branch => 'Transport'

  gem "berkshelf"
  gem "vagrant-wrapper", ">= 2.0"
end
