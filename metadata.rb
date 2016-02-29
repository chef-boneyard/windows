name             'windows'
maintainer       'Chef Software, Inc.'
maintainer_email 'cookbooks@chef.io'
license          'Apache 2.0'
description      'Provides a set of useful Windows-specific primitives.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.39.2'
supports         'windows'
source_url       'https://github.com/chef-cookbooks/windows' if respond_to?(:source_url)
issues_url       'https://github.com/chef-cookbooks/windows/issues' if respond_to?(:issues_url)
depends          'chef_handler'
