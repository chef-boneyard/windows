name             'windows'
maintainer       'Chef Software, Inc.'
maintainer_email 'cookbooks@chef.io'
license          'Apache 2.0'
description      'Provides a set of useful Windows-specific primitives.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '2.1.1'
supports         'windows'
depends          'ohai', '>= 4.0.0'
source_url       'https://github.com/chef-cookbooks/windows'
issues_url       'https://github.com/chef-cookbooks/windows/issues'
chef_version     '>= 12.1' if respond_to?(:chef_version)
