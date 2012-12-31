require 'resolv'

actions :create, :delete

default_action :create

attribute :device_id, :kind_of => String, :name_attribute => true,
            :required => true
attribute :comment, :kind_of => String

attribute :default, :kind_of => [ TrueClass, FalseClass ], :default => false
attribute :driver_name, :kind_of => String, :required => true
attribute :location, :kind_of => String
attribute :shared, :kind_of => [ TrueClass, FalseClass ], :default => false
attribute :share_name, :kind_of => String

attribute :ipv4_address, :kind_of => String, :regex => Resolv::IPv4::Regex

attr_accessor :exists
