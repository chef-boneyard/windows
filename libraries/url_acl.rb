#
# Author:: Malte Witt (<malte.witt@cp.ag>)
# Cookbook Name:: windows
# Library:: UrlAcl
#
# Copyright:: 2011-2015, Chef Software, Inc.
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

require 'ffi'

module Windows
  module UrlAcl
    module HttpApi
      extend FFI::Library
      ffi_lib 'httpapi'

      HTTP_INITIALIZE_CONFIG = 2 unless defined? HTTP_INITIALIZE_CONFIG

      enum :http_service_config_query_type, [:http_service_config_query_exact, 0,
                                             :http_service_config_next,
                                             :http_service_config_max]

      enum :http_service_config_id, [:http_service_config_ip_listen_list, 0,
                                     :http_service_config_ssl_cert_info,
                                     :http_service_config_urlacl_info,
                                     :http_service_config_timeout,
                                     :http_service_config_cache,
                                     :http_service_config_ssl_sni_cert_info,
                                     :http_service_config_max]

      class HTTPApiVersion < FFI::Struct
        layout :http_api_major_version, :ushort,
               :http_api_minor_version, :ushort
      end

      class HTTPServiceConfigURLACLKey < FFI::Struct
        layout :url_prefix, :pointer
      end

      class HTTPServiceConfigURLACLParam < FFI::Struct
        layout :string_security_descriptor, :pointer
      end

      class HTTPServiceConfigURLACLQuery < FFI::Struct
        layout :query_desc, :http_service_config_query_type,
               :key_desc, HTTPServiceConfigURLACLKey,
               :token, :uint
      end

      class HTTPServiceConfigURLACLSet < FFI::Struct
        layout :key_desc, HTTPServiceConfigURLACLKey,
               :param_desc, HTTPServiceConfigURLACLParam
      end

      attach_function(
        :http_initialize,
        :HttpInitialize,
        [HTTPApiVersion.by_value, :ulong, :pointer],
        :ulong
      )
      attach_function(
        :http_terminate,
        :HttpTerminate,
        [:ulong, :pointer],
        :ulong
      )
      attach_function(
        :http_query_service_configuration,
        :HttpQueryServiceConfiguration,
        [:pointer, :http_service_config_id, :pointer, :ulong, :pointer, :ulong, :pointer, :pointer],
        :ulong
      )
    end

    module Advapi32
      extend FFI::Library
      ffi_lib 'advapi32'

      attach_function(
        :convert_string_sid_to_sid,
        :ConvertStringSidToSidW,
        [:pointer, :pointer],
        :int
      )

      attach_function(
        :lookup_account_sid,
        :LookupAccountSidW,
        [:pointer, :pointer, :pointer, :pointer, :pointer, :pointer, :pointer],
        :int
      )
    end

    module Kernel32
      extend FFI::Library
      ffi_lib 'kernel32'

      attach_function(
        :local_free,
        :LocalFree,
        [:pointer],
        :pointer
      )
    end

    module ErrorCodes
      ERROR_SUCCESS = 0 unless defined? ERROR_SUCCESS
      ERROR_INVALID_FUNCTION = 1 unless defined? ERROR_INVALID_FUNCTION
      ERROR_FILE_NOT_FOUND = 2 unless defined? ERROR_FILE_NOT_FOUND
      ERROR_INVALID_HANDLE = 6 unless defined? ERROR_INVALID_HANDLE
      ERROR_INSUFFICIENT_BUFFER = 122 unless defined? ERROR_INSUFFICIENT_BUFFER
    end

    def get_urlacl(url)
      initialize_http
      begin
        security_descriptor = get_security_descriptor(url)
        sids = get_sids(security_descriptor)
        sids.map { |sid| get_user(sid) }
      ensure
        terminate_http
      end
    end

    private

    def initialize_http
      api_version = HttpApi::HTTPApiVersion.new
      api_version[:http_api_major_version] = 1
      api_version[:http_api_minor_version] = 0

      hresult = HttpApi.http_initialize(api_version, HttpApi::HTTP_INITIALIZE_CONFIG, nil)

      raise "Unexcpected HRESULT #{hresult} [HttpApi.http_initialize]" \
          unless 0 == hresult
    end

    def terminate_http
      HttpApi.http_terminate(HttpApi::HTTP_INITIALIZE_CONFIG, nil)
    end

    def get_security_descriptor(url)
      url_utf16 = url.encode(Encoding::UTF_16LE)
      ptr_url_utf16 = FFI::MemoryPointer.new(:ushort, url_utf16.length + 1, true).put_bytes(0, url_utf16)

      input_config_info = HttpApi::HTTPServiceConfigURLACLQuery.new
      input_config_info[:query_desc] = :http_service_config_query_exact
      input_config_info[:key_desc][:url_prefix] = ptr_url_utf16
      input_config_info[:token] = 0
      ptr_return_length = FFI::MemoryPointer.new(:int, 1)

      # First request to get needed buffer_size. Expecting ERROR_INSUFFICIENT_BUFFER
      # or URL not found
      hresult = HttpApi.http_query_service_configuration(
        nil,
        :http_service_config_urlacl_info,
        input_config_info.to_ptr,
        input_config_info.size,
        nil,
        0,
        ptr_return_length,
        nil)

      return '' if 2 == hresult

      raise "Unexcpected HRESULT #{hresult} [HttpApi.http_query_service_configuration]" \
          unless ErrorCodes::ERROR_INSUFFICIENT_BUFFER == hresult

      buffer_size = ptr_return_length.read_int
      ptr_output_config_info = FFI::MemoryPointer.new(:char, buffer_size)

      # Second request is expected to succeed
      hresult = HttpApi.http_query_service_configuration(
        nil,
        :http_service_config_urlacl_info,
        input_config_info.to_ptr,
        input_config_info.size,
        ptr_output_config_info,
        buffer_size,
        ptr_return_length,
        nil)

      raise "Unexcpected HRESULT #{hresult} [HttpApi.http_query_service_configuration]" \
          unless 0 == hresult

      output_config_info = HttpApi::HTTPServiceConfigURLACLSet.new(ptr_output_config_info)
      read_utf16(output_config_info[:param_desc][:string_security_descriptor])
    end

    def read_utf16(mem_pointer)
      index = 0
      wchar = 0
      result = []
      loop do
        wchar = mem_pointer.get_uint16(2 * index)
        break if 0 == wchar
        result.push(wchar)
        index += 1
      end

      result.pack('s*').force_encoding(Encoding::UTF_16LE).encode(Encoding::UTF_8)
    end

    def get_sids(security_descriptor)
      match_data = security_descriptor.scan(/\([^\)]+\)/)
      sids = []
      match_data.each do |sd|
        sid_string = sd.match(/\(A;;G\w{1};;;([^\)]+)/)[1].encode(Encoding::UTF_16LE)
        sids.push(sid_string)
      end
      sids
    end

    def get_user(sid_string)
      ptr_string_sid = FFI::MemoryPointer.new(:ushort, sid_string.length + 1).put_bytes(0, sid_string)
      ptr_ptr_sid = FFI::MemoryPointer.new(:pointer, 1)
      success = Advapi32.convert_string_sid_to_sid(ptr_string_sid, ptr_ptr_sid)

      raise 'Advapi32.convert_string_sid_to_sid failed' unless 0 != success

      ptr_cch_name = FFI::MemoryPointer.new(:uint, 1)
      ptr_cch_domain = FFI::MemoryPointer.new(:uint, 1)
      ptr_sid_name_use = FFI::MemoryPointer.new(:int, 1)

      # First call to get needed buffer sizes
      Advapi32.lookup_account_sid(
        nil,
        ptr_ptr_sid.read_pointer,
        nil,
        ptr_cch_name,
        nil,
        ptr_cch_domain,
        ptr_sid_name_use)

      ptr_name = FFI::MemoryPointer.new(:ushort, ptr_cch_name.read_uint)
      ptr_domain = FFI::MemoryPointer.new(:ushort, ptr_cch_domain.read_uint)
      success = Advapi32.lookup_account_sid(
        nil,
        ptr_ptr_sid.read_pointer,
        ptr_name,
        ptr_cch_name,
        ptr_domain,
        ptr_cch_domain,
        ptr_sid_name_use)

      raise 'Advapi32.lookup_account_sid failed' unless 0 != success

      name = read_utf16(ptr_name)
      domain = read_utf16(ptr_domain)
      domain = nil if domain.empty?

      return { domain: domain, user: name }
    ensure
      ptr_sid = ptr_ptr_sid.read_pointer
      Kernel32.local_free(ptr_sid) unless ptr_sid.null?
    end
  end
end
