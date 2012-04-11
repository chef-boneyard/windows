# patch to fix CHEF-2684
if RUBY_VERSION =~ /^1\.8/
  begin
    require 'win32/open3'
  rescue LoadError
    require 'open3'
  end
else
  require 'open3'
end

class Chef
  module Mixin
    module Command
      module Windows

        module Open4
          def self.popen4(*cmd, &block)
            Open3.popen3(*cmd) do |i, o, e, t|
              block.call(i, o, e, t.pid)
            end
          end
        end

      end
    end
  end
end
