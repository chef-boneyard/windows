#
# Author:: Piyush Awasthi (<piyush.awasthi@chef.io>)
# Cookbook:: windows
# Library:: win32_certstore_helper
#
# Copyright:: 2011-2018, Chef Software, Inc.
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

require 'win32-certstore'
require 'openssl'
require 'chef/mixin/powershell_out'

module Win32
  module Helper
    include Chef::Mixin::PowershellOut

    def openssl_cert_obj
      OpenSSL::X509::Certificate.new(raw_source)
    end

    def add_cert(cert_obj)
      store = ::Win32::Certstore.open(store_name)
      store.add(cert_obj)
    end

    def delete_cert
      store = ::Win32::Certstore.open(store_name)
      store.delete(source)
    end

    def raw_source
      ext = File.extname(source)
      convert_pem(ext, source)
    end

    private

    def convert_pem(ext, source)
      out = case ext
            when '.crt', '.der'
              powershell_out("openssl x509 -text -inform DER -in #{source} -outform PEM").stdout
            when '.cer'
              powershell_out("openssl x509 -text -inform DER -in #{source} -outform PEM").stdout
            when '.pfx'
              powershell_out("openssl pkcs12 -in #{source} -nodes -passin pass:#{pfx_password}").stdout
            when '.p7b'
              powershell_out("openssl pkcs7 -print_certs -in #{source} -outform PEM").stdout
            end
      out = File.read(source) if out.nil? || out.empty?
      format_raw_out(out)
    end

    def format_raw_out(out)
      begin_cert = '-----BEGIN CERTIFICATE-----'
      end_cert = '-----END CERTIFICATE-----'
      begin_cert + out[/#{begin_cert}(.*?)#{end_cert}/m, 1] + end_cert
    end
  end
end
