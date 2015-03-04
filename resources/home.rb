actions :create

default_action :create

attribute :name, :kind_of => String, :name_attribute => true
attribute :password, :kind_of => String

# Covers 0.10.8 and earlier
def initialize(*args)
  super
  @action = :create
end
