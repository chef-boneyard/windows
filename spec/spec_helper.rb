require 'chefspec'
require 'chefspec/berkshelf'
require 'chefspec/cacher'

RSpec.configure do |config|
  config.log_level = :fatal
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.order = 'random'
  config.platform = 'windows'
  config.version = '2012R2'
end

at_exit { ChefSpec::Coverage.report! }
