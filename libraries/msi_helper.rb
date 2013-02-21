#
# Author:: James Kessler (<james.kessler@tradingtechnologies.com>) 
# Cookbook Name:: windows
# Provider:: helper
#
# Copyright:: 2013, Trading Technologies, Inc.
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

if RUBY_PLATFORM =~ /mswin|mingw32|windows/
  require 'win32ole'
end

module Windows
  module MsiHelper

    class MsiPackage
      attr_reader :msisource, :property

      MSIDBOPEN_READONLY = 0
      INSTALLSTATE_DEFAULT = 5

      def initialize(msisource)
        @msisource = msisource
      end

      def installer
        WIN32OLE.new("WindowsInstaller.Installer")
      end

      def property(name)
        db = self.installer.OpenDatabase(@msisource, MSIDBOPEN_READONLY)
        view = db.OpenView("SELECT Value FROM Property WHERE Property='#{name}'")
        view.Execute()
        record = view.Fetch()
        record ? record.StringData(1) : nil
      end

      def installed?
        product_code = self.property("ProductCode")
        self.installer.ProductState(product_code) == INSTALLSTATE_DEFAULT ? true : false
      end
    end

  end
end