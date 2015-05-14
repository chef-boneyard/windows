name             'windows'
maintainer       'Chef Software, Inc.'
maintainer_email 'cookbooks@chef.io'
license          'Apache 2.0'
description      'Provides a set of useful Windows-specific primitives.'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.37.0'
supports         'windows'
source_url       "https://github.com/opscode-cookbooks/windows"
issues_url       "https://github.com/opscode-cookbooks/windows/issues"
depends          'chef_handler'
