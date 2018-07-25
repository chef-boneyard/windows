require 'chefspec'
require 'chefspec/berkshelf'
require 'win32-certstore'

RSpec.configure do |config|
  config.color = true               # Use color in STDOUT
  config.formatter = :documentation # Use the specified formatter
  config.log_level = :error         # Avoid deprecation notice SPAM
end
