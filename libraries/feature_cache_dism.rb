#
# Author:: Tim Smith (<tsmith@chef.io>)
# Cookbook:: windows
# Library:: feature_cache_dism
#
# Copyright:: 2018, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/shell_out'
require 'chef/node/attribute_collections'

class DismCache
  include Singleton
  include Chef::Mixin::ShellOut

  # run dism.exe to get a list of all available features. Create a hash with 'disabled',
  # 'enabled', and 'removed' arrays and parse the features into those arrays
  # We do this because getting a list of features in dism takes at least a second
  # and this data will be persisted across multiple resource runs which gives us
  # a much faster run when no features actually need to be installed / removed.
  # @return [Hash] hash containing 'enabled', 'disabled' and 'removed' arrays
  def data
    @data ||= begin
      data = Mash.new
      data['enabled'] = []
      data['disabled'] = []
      data['removed'] = []

      # Grab raw feature information from dism command line
      raw_feature_shellout = shell_out('dism.exe /Get-Features /Online /Format:Table /English').stdout

      # Split stdout into an array by windows line ending
      feature_shellout_array = raw_feature_shellout.split("\r\n")
      feature_shellout_array.each do |line|
        case line
        when /Payload Removed/ # matches 'Disabled with Payload Removed'
          data['removed'] << parse_feature_line(line)
        when /Enable/ # matches 'Enabled' and 'Enable Pending' aka after reboot
          data['enabled'] << parse_feature_line(line)
        when /Disable/ # matches 'Disabled' and 'Disable Pending' aka after reboot
          data['disabled'] << parse_feature_line(line)
        end
      end
      data
    end
  end

  # parse the feature string lines by stripping trailing whitespace characters
  # and then splitting on n number of spaces. downcases the values unless we're
  # on windows < 6.2 where that would break things. + | +  n number of spaces
  # @return [String] the feature name
  def parse_feature_line(line)
    feature = line.strip.split(/\s+[|]\s+/).first

    # dism on windows 2012+ isn't case sensitive so it's best to compare
    # lowercase lists so the user input doesn't need to be case sensitive
    # @todo when we're ready to remove windows 2008R2 the gating here can go away
    feature.downcase! unless Chef.node['platform_version'][/^(\d+\.\d+)/, 1].to_f < 6.2

    feature
  end

  # simple forces the data to regenerate the mash
  # @return [void]
  def reset
    @data = nil
  end
end
