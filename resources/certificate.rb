#
# Author:: Richard Lavey (richard.lavey@calastone.com)
# Cookbook:: windows
# Resource:: certificate
#
# Copyright:: 2015-2017, Calastone Ltd.
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

include Windows::Helper

property :source, String, name_property: true, required: true
property :pfx_password, String
property :pfx_exportable, [true, false], default: false
property :pfx_prefer_cng_ksp, [true, false], default: false
property :pfx_always_cng_ksp, [true, false], default: false
property :private_key_acl, Array
property :store_name, String, default: 'MY', regex: /^(?:MY|CA|ROOT|TrustedPublisher|TRUSTEDPEOPLE)$/
property :user_store, [true, false], default: false

action :create do
  hash = '$cert.GetCertHashString()'
  code_script = <<-EOH
#{library_script}
#{import_cert_script}
#{acl_script(hash)}
EOH

  guard_script = cert_script(false) <<
                 cert_exists_script(hash)

  converge_by("adding certificate #{new_resource.source} into #{new_resource.store_name} to #{cert_location}\\#{new_resource.store_name}") do
    powershell_script new_resource.name do
      guard_interpreter :powershell_script
      convert_boolean_return true
      code code_script
      not_if guard_script
    end
  end
end

# acl_add is a modify-if-exists operation : not idempotent
action :acl_add do
  code_script = library_script
  guard_script = library_script

  if ::File.exist?(new_resource.source)
    hash = '$cert.GetCertHashString()'
    code_script << cert_script(false)
    guard_script << cert_script(false)
  else
    # make sure we have no spaces in the hash string
    hash = "\"#{new_resource.source.gsub(/\s/, '')}\""
  end
  code_script << acl_script(hash)
  guard_script << cert_exists_script(hash)

  converge_by("setting the acls on #{new_resource.source} in #{cert_location}\\#{new_resource.store_name}") do
    powershell_script new_resource.name do
      guard_interpreter :powershell_script
      convert_boolean_return true
      code code_script
      only_if guard_script
    end
  end
end

action :delete do
  # do we have a hash or a subject?
  # TODO: It's a bit annoying to know the thumbprint of a cert you want to remove when you already
  # have the file.  Support reading the hash directly from the file if provided.
  search = if new_resource.source =~ /^[a-fA-F0-9]{40}$/
             "Thumbprint -eq '#{new_resource.source}'"
           else
             "Subject -like '*#{new_resource.source.sub(/\*/, '`*')}*'" # escape any * in the source
           end
  cert_command = "Get-ChildItem Cert:\\#{cert_location}\\#{new_resource.store_name} | where { $_.#{search} }"

  code_script = within_store_script do |store|
    <<-EOH
foreach ($c in #{cert_command})
{
  #{store}.Remove($c)
}
EOH
  end
  guard_script = "@(#{cert_command}).Count -gt 0\n"
  converge_by("Removing certificate #{new_resource.source} from #{cert_location}\\#{new_resource.store_name}") do
    powershell_script new_resource.name do
      guard_interpreter :powershell_script
      convert_boolean_return true
      code code_script
      only_if guard_script
    end
  end
end

action_class do
  def cert_location
    @location ||= new_resource.user_store ? 'CurrentUser' : 'LocalMachine'
  end

  def cert_script(persist)
    cert_script = '$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2'
    file = win_friendly_path(new_resource.source)
    cert_script << " \"#{file}\""
    if ::File.extname(file.downcase) == '.pfx'
      cert_script << ", \"#{new_resource.pfx_password}\""
      if persist && new_resource.user_store
        cert_script << ', [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet'
      elsif persist
        cert_script << ', ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeyset)'
      end
    end
    cert_script << "\n"
  end

  def cert_exists_script(hash)
    <<-EOH
  $hash = #{hash}
  Test-Path "Cert:\\#{cert_location}\\#{new_resource.store_name}\\$hash"
  EOH
  end

  def within_store_script
    inner_script = yield '$store'
    <<-EOH
  $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "#{new_resource.store_name}", ([System.Security.Cryptography.X509Certificates.StoreLocation]::#{cert_location})
  $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
  #{inner_script}
  $store.Close()
  EOH
end

  def import_cert_script
    file = win_friendly_path(new_resource.source)
    pfxOptions = ['[Crypto.Win+PfxCertStoreFlags]::PKCS12_INCLUDE_EXTENDED_PROPERTIES', '[Crypto.Win+PfxCertStoreFlags]::PKCS12_ALLOW_OVERWRITE_KEY']
    if !new_resource.user_store 
        pfxOptions << '[Crypto.Win+PfxCertStoreFlags]::CRYPT_MACHINE_KEYSET'
    end
    if new_resource.pfx_exportable
        pfxOptions << '[Crypto.Win+PfxCertStoreFlags]::CRYPT_EXPORTABLE'
    end
    if new_resource.pfx_prefer_cng_ksp
        pfxOptions << '[Crypto.Win+PfxCertStoreFlags]::PKCS12_PREFER_CNG_KSP'
    end
    if new_resource.pfx_always_cng_ksp
        pfxOptions << '[Crypto.Win+PfxCertStoreFlags]::PKCS12_ALLOW_OVERWRITE_KEY'
    end        

    if ::File.extname(file.downcase) == '.pfx'
      set_import_cert_script = <<-EOH
$CertificatePath = '#{file}'
$Password = '#{new_resource.pfx_password}'
$Location = '#{cert_location}'
$StoreName = '#{new_resource.store_name}'
$pfxOptions = #{pfxOptions * " -bor "}

[Crypto.PfxHelper]::ImportPfx($CertificatePath,$Password,$Location,$StoreName,$pfxOptions)

#{cert_script(false)}
EOH
    else
      set_import_cert_script = <<-EOH2
#{cert_script(true)}
#{within_store_script { |store| store + '.Add($cert)' }}
EOH2
    end
    set_import_cert_script
  end

  def acl_script(hash)
    return '' if new_resource.private_key_acl.nil? || new_resource.private_key_acl.empty?
    set_acl_script = <<-EOH
  $hash = #{hash}
  $Location = '#{cert_location}'
  $StoreName = '#{new_resource.store_name}'
  
  $CertificatePath = "cert:\\$($Location)\\$($StoreName)\\$($hash)"
  $Certificate = Get-ChildItem $CertificatePath
  if ($Certificate -eq $null) { 
	  throw 'no certificate exists for: $CertificatePath' 
  }
  
  $CertificateTriage = [Crypto.AclHelper]::TriageAcquireKeyHandle($Certificate)
  
  EOH
    new_resource.private_key_acl.each do |name|
      set_acl_script << "$CertificateTriage.Acl = $CertificateTriage.Acl | Add-AccessRule -UserAccount '#{name}' -FileSystemRights ReadAndExecute -AccessControlType Allow\n"
    end
    set_acl_script
  end


  def library_script
    # Most of this PS came from https://www.powershellgallery.com/packages/GuardedFabricTools/0.2.0/Content/CertificateManagement.psm1

    set_library_script = <<-EOH
function Test-Nano
{
    $EditionId = (Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion' -Name 'EditionID').EditionId

    return (($EditionId -eq "ServerStandardNano") -or
            ($EditionId -eq "ServerDataCenterNano") -or
            ($EditionId -eq "NanoServer") -or
            ($EditionId -eq "ServerTuva"))
}


$ncryptDll = "ncrypt.dll"
$crypt32Dll = "crypt32.dll"

if (-not (Test-Nano))
{
    Write-Verbose "Not running on Nano, using default Win32 binaries."
    $securityDll = "advapi32.dll"
    $capiDll = "advapi32.dll"
    $references = @()
    $PrepareConstrainedRegions = "RuntimeHelpers.PrepareConstrainedRegions();"
}
else
{
    Write-Verbose "Running on Nano, using API sets."
    $securityDll = "api-ms-win-security-base-l1-2-0"
    $capiDll = "api-ms-win-security-cryptoapi-l1-1-0"
    $PrepareConstrainedRegions = "";
    $references =   "System.Security.Cryptography.X509Certificates.dll", `
                    "System.Security.Cryptography.Cng.dll", `
                    "System.IO.FileSystem.AccessControl.dll", `
                    "System.Runtime.Handles.dll", `
                    "System.Security.AccessControl.dll", `
                    "Microsoft.Win32.Primitives.dll" | % { Join-Path "C:\\Windows\\system32\\DotNetCore\\v1.0\\" $_ }
}

$source = @" 
using System; 
using System.Collections.Generic; 
using System.ComponentModel; 
using System.Runtime.CompilerServices; 
using System.Runtime.InteropServices; 
using System.Security.AccessControl; 
using System.Security.Cryptography.X509Certificates; 
using System.Text; 
using System.Threading.Tasks; 
using Microsoft.Win32.SafeHandles; 
 
namespace Crypto 
{ 
    public static class Win
    {
        private const string NCRYPT = "$ncryptDll";
        private const string CRYPT32 = "$crypt32Dll";
        private const string APIMSWINSECURITYBASE = "$securityDll";
        private const string APIMSWINSECURITYCRYPTOAPI = "$capiDll";

        internal const string NCRYPT_SECURITY_DESCR_PROPERTY = "Security Descr";

        [Flags]
        public enum SECURITY_INFORMATION : uint
        {
            OWNER_SECURITY_INFORMATION = 0x00000001,
            GROUP_SECURITY_INFORMATION = 0x00000002,
            DACL_SECURITY_INFORMATION = 0x00000004,
            SACL_SECURITY_INFORMATION = 0x00000008,
            UNPROTECTED_SACL_SECURITY_INFORMATION = 0x10000000,
            UNPROTECTED_DACL_SECURITY_INFORMATION = 0x20000000,
            PROTECTED_SACL_SECURITY_INFORMATION = 0x40000000,
            PROTECTED_DACL_SECURITY_INFORMATION = 0x80000000
        }

        [Flags]
        private enum CryptAcquireKeyFlagControl : uint
        {
            CRYPT_ACQUIRE_ALLOW_NCRYPT_KEY_FLAG = 0x00010000,
            CRYPT_ACQUIRE_PREFER_NCRYPT_KEY_FLAG = 0x00020000,
            CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG = 0x00040000,
        }

        [Flags]
        public enum CryptAcquireKeyFlags : uint
        {
            CRYPT_ACQUIRE_CACHE_FLAG = 0x00000001,
            CRYPT_ACQUIRE_USE_PROV_INFO_FLAG = 0x00000002,
            CRYPT_ACQUIRE_COMPARE_KEY_FLAG = 0x00000004,
            CRYPT_ACQUIRE_NO_HEALING = 0x00000008,
            CRYPT_ACQUIRE_SILENT_FLAG = 0x00000040,
        }

        [Flags]
        public enum CryptAcquireNCryptKeyFlags : uint
        {
            CRYPT_ACQUIRE_CACHE_FLAG = CryptAcquireKeyFlags.CRYPT_ACQUIRE_CACHE_FLAG | CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG,
            CRYPT_ACQUIRE_USE_PROV_INFO_FLAG = CryptAcquireKeyFlags.CRYPT_ACQUIRE_USE_PROV_INFO_FLAG | CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG,
            CRYPT_ACQUIRE_COMPARE_KEY_FLAG = CryptAcquireKeyFlags.CRYPT_ACQUIRE_COMPARE_KEY_FLAG | CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG,
            CRYPT_ACQUIRE_NO_HEALING = CryptAcquireKeyFlags.CRYPT_ACQUIRE_NO_HEALING | CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG,
            CRYPT_ACQUIRE_SILENT_FLAG = CryptAcquireKeyFlags.CRYPT_ACQUIRE_SILENT_FLAG | CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG,
        }

        public enum ErrorCode
        {
            Success = 0, // ERROR_SUCCESS 
            BadSignature = unchecked((int)0x80090006), // NTE_BAD_SIGNATURE 
            NotFound = unchecked((int)0x80090011), // NTE_NOT_FOUND 
            KeyDoesNotExist = unchecked((int)0x80090016), // NTE_BAD_KEYSET 
            BufferTooSmall = unchecked((int)0x80090028), // NTE_BUFFER_TOO_SMALL 
            NoMoreItems = unchecked((int)0x8009002a), // NTE_NO_MORE_ITEMS 
            NotSupported = unchecked((int)0x80090029) // NTE_NOT_SUPPORTED 
        }

        [Flags]
        public enum KeySpec : uint
        {
            NONE = 0x0,
            AT_KEYEXCHANGE = 0x1,
            AT_SIGNATURE = 2,
            CERT_NCRYPT_KEY_SPEC = 0xFFFFFFFF
        }

        public enum ProvParam : uint
        {
            PP_ENUMALGS = 1,
            PP_ENUMCONTAINERS = 2,
            PP_IMPTYPE = 3,
            PP_NAME = 4,
            PP_VERSION = 5,
            PP_CONTAINER = 6,
            PP_CHANGE_PASSWORD = 7,
            PP_KEYSET_SEC_DESCR = 8, // get/set security descriptor of keyset 
            PP_CERTCHAIN = 9, // for retrieving certificates from tokens 
            PP_KEY_TYPE_SUBTYPE = 10,
            PP_PROVTYPE = 16,
            PP_KEYSTORAGE = 17,
            PP_APPLI_CERT = 18,
            PP_SYM_KEYSIZE = 19,
            PP_SESSION_KEYSIZE = 20,
            PP_UI_PROMPT = 21,
            PP_ENUMALGS_EX = 22,
            PP_ENUMMANDROOTS = 25,
            PP_ENUMELECTROOTS = 26,
            PP_KEYSET_TYPE = 27,
            PP_ADMIN_PIN = 31,
            PP_KEYEXCHANGE_PIN = 32,
            PP_SIGNATURE_PIN = 33,
            PP_SIG_KEYSIZE_INC = 34,
            PP_KEYX_KEYSIZE_INC = 35,
            PP_UNIQUE_CONTAINER = 36,
            PP_SGC_INFO = 37,
            PP_USE_HARDWARE_RNG = 38,
            PP_KEYSPEC = 39,
            PP_ENUMEX_SIGNING_PROT = 40,
            PP_CRYPT_COUNT_KEY_USE = 41,
        }

        [Flags]
        public enum StoreLocationFlags : uint
        {
            CERT_SYSTEM_STORE_UNPROTECTED_FLAG = 0x40000000,
            CERT_SYSTEM_STORE_LOCATION_MASK = 0x00FF0000,
            CERT_SYSTEM_STORE_LOCATION_SHIFT = 16,
            CERT_SYSTEM_STORE_CURRENT_USER_ID = 1,
            CERT_SYSTEM_STORE_LOCAL_MACHINE_ID = 2,
            CERT_SYSTEM_STORE_CURRENT_SERVICE_ID = 4,
            CERT_SYSTEM_STORE_SERVICES_ID = 5,
            CERT_SYSTEM_STORE_USERS_ID = 6,
            CERT_SYSTEM_STORE_CURRENT_USER_GROUP_POLICY_ID = 7,
            CERT_SYSTEM_STORE_LOCAL_MACHINE_GROUP_POLICY_ID = 8,
            CERT_SYSTEM_STORE_LOCAL_MACHINE_ENTERPRISE_ID = 9,
            CERT_SYSTEM_STORE_CURRENT_USER = ((int)CERT_SYSTEM_STORE_CURRENT_USER_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_LOCAL_MACHINE = ((int)CERT_SYSTEM_STORE_LOCAL_MACHINE_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_CURRENT_SERVICE = ((int)CERT_SYSTEM_STORE_CURRENT_SERVICE_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_SERVICES = ((int)CERT_SYSTEM_STORE_SERVICES_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_USERS = ((int)CERT_SYSTEM_STORE_USERS_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_CURRENT_USER_GROUP_POLICY = ((int)CERT_SYSTEM_STORE_CURRENT_USER_GROUP_POLICY_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_LOCAL_MACHINE_GROUP_POLICY = ((int)CERT_SYSTEM_STORE_LOCAL_MACHINE_GROUP_POLICY_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT),
            CERT_SYSTEM_STORE_LOCAL_MACHINE_ENTERPRISE = ((int)CERT_SYSTEM_STORE_LOCAL_MACHINE_ENTERPRISE_ID << (int)CERT_SYSTEM_STORE_LOCATION_SHIFT)
        }

        [Flags]
        public enum PfxCertStoreFlags : uint
        {
            CRYPT_EXPORTABLE = 0x00000001,
            CRYPT_USER_PROTECTED = 0x00000002,
            CRYPT_MACHINE_KEYSET = 0x00000020,
            CRYPT_USER_KEYSET = 0x00001000,
            PKCS12_PREFER_CNG_KSP = 0x00000100,
            PKCS12_ALWAYS_CNG_KSP = 0x00000200,
            PKCS12_ALLOW_OVERWRITE_KEY = 0x00004000,
            PKCS12_NO_PERSIST_KEY = 0x00008000,
            PKCS12_INCLUDE_EXTENDED_PROPERTIES = 0x00000010,
            None = 0x00000000,
        }

        public enum CertStoreProvider : int
        {
            CERT_STORE_PROV_MEMORY = 2,
            CERT_STORE_PROV_SYSTEM = 10,
        }

        public enum CertStoreAddDisposition : int
        {
            CERT_STORE_ADD_NEW = 1,
            CERT_STORE_ADD_USE_EXISTING = 2,
            CERT_STORE_ADD_REPLACE_EXISTING = 3,
            CERT_STORE_ADD_ALWAYS = 4,
            CERT_STORE_ADD_REPLACE_EXISTING_INHERIT_PROPERTIES = 5,
            CERT_STORE_ADD_NEWER = 6,
            CERT_STORE_ADD_NEWER_INHERIT_PROPERTIES = 7,
        }

        public enum CertStoreCloseDisposition : int
        {
            NONE = 0,
            CERT_CLOSE_STORE_FORCE_FLAG = 0x1,
            CERT_CLOSE_STORE_CHECK_FLAG = 0x2,
        }

        public enum ProviderType : uint
        {
            CNG = 0,
            PROV_RSA_FULL = 1,
            PROV_RSA_SIG = 2,
            PROV_DSS = 3,
            PROV_FORTEZZA = 4,
            PROV_MS_EXCHANGE = 5,
            PROV_SSL = 6,
            PROV_RSA_SCHANNEL = 12,
            PROV_DSS_DH = 13,
            PROV_EC_ECDSA_SIG = 14,
            PROV_EC_ECNRA_SIG = 15,
            PROV_EC_ECDSA_FULL = 16,
            PROV_EC_ECNRA_FULL = 17,
            PROV_DH_SCHANNEL = 18,
            PROV_SPYRUS_LYNKS = 20,
            PROV_RNG = 21,
            PROV_INTEL_SEC = 22,
            PROV_REPLACE_OWF = 23,
            PROV_RSA_AES = 24,
        }

        [Flags]
        public enum ProviderKeyFlags : uint
        {
            CERT_SET_KEY_PROV_HANDLE_PROP_ID_OR_CERT_SET_KEY_CONTEXT_PROP_ID = 1,
            CRYPT_MACHINE_KEYSET_OR_NCRYPT_MACHINE_KEY_FLAG = 32,
            CRYPT_SILENT_OR_NCRYPT_SILENT_FLAG = 64,
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct CRYPT_DATA_BLOB
        {
            public int cbData;
            public IntPtr pbData;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct CERT_CONTEXT
        {
            public uint dwCertEncodingType;
            [MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 2)]
            public byte[] pbCertEncoded;
            public uint cbCertEncoded;
            public IntPtr pCertInfo;
            public IntPtr hCertStore;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct CRYPT_KEY_PROV_INFO
        {
            [MarshalAs(UnmanagedType.LPWStr)]
            public string pwszContainerName;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string pwszProvName;
            public ProviderType dwProvType;
            public ProviderKeyFlags dwFlags;
            public uint cProvParam;
            public IntPtr rgProvParam;
            public KeySpec dwKeySpec;
        }

        [DllImport(APIMSWINSECURITYBASE, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetSecurityDescriptorDacl(
            IntPtr pSecurityDescriptor,
            [MarshalAs(UnmanagedType.Bool)] out bool bDaclPresent,
            ref IntPtr pDacl,
            [MarshalAs(UnmanagedType.Bool)] out bool bDaclDefaulted);

        [DllImport(NCRYPT, CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern ErrorCode NCryptGetProperty(
            SafeHandle hObject,
            [MarshalAs(UnmanagedType.LPWStr)] string pszProperty,
            SafeSecurityDescriptorPtr pbOutput,
            uint cbOutput,
            ref uint pcbResult,
            SECURITY_INFORMATION dwFlags);

        [DllImport(NCRYPT, CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern ErrorCode NCryptSetProperty(
            SafeHandle hObject,
            [MarshalAs(UnmanagedType.LPWStr)] string pszProperty,
            [MarshalAs(UnmanagedType.LPArray)] byte[] pbInput,
            uint cbInput,
            SECURITY_INFORMATION dwFlags);

        [DllImport(CRYPT32, CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CryptAcquireCertificatePrivateKey(
            IntPtr pCert,
            CryptAcquireKeyFlags dwFlags,
            IntPtr pvParameters,
            out SafeCryptProviderHandle phCryptProvOrNCryptKey,
            out KeySpec pdwKeySpec,
            out bool pfCallerFreeProvOrNCryptKey);

        [DllImport(CRYPT32, CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CryptAcquireCertificatePrivateKey(
            IntPtr pCert,
            CryptAcquireNCryptKeyFlags dwFlags,
            IntPtr pvParameters,
            out SafeNCryptKeyHandle phCryptProvOrNCryptKey,
            out KeySpec pdwKeySpec,
            out bool pfCallerFreeProvOrNCryptKey);

        [DllImport(APIMSWINSECURITYCRYPTOAPI, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CryptContextAddRef(
            SafeCryptProviderHandle hProv,
            IntPtr pdwReserved,
            uint dwFlags);

        [DllImport(APIMSWINSECURITYCRYPTOAPI, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CryptReleaseContext(
            IntPtr hProv,
            uint dwFlags);

        [DllImport(APIMSWINSECURITYCRYPTOAPI, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CryptGetProvParam(
            SafeHandle hProv,
            ProvParam dwParam,
            SafeSecurityDescriptorPtr pbData,
            ref uint pdwDataLen,
            SECURITY_INFORMATION dwFlags);

        [DllImport(APIMSWINSECURITYCRYPTOAPI, CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CryptSetProvParam(
            SafeHandle hProv,
            ProvParam dwParam,
            [MarshalAs(UnmanagedType.LPArray)] byte[] pbData,
            SECURITY_INFORMATION dwFlags);
        
        [DllImport(CRYPT32, CharSet = CharSet.Auto, SetLastError = true)]
        public static extern IntPtr CertOpenStore(
            CertStoreProvider storeProvider,
            uint dwMsgAndCertEncodingType,
            IntPtr hCryptProv,
            StoreLocationFlags dwFlags,
            string cchNameString);

        [DllImport(CRYPT32, SetLastError = true)]
        public static extern IntPtr PFXImportCertStore(
            ref CRYPT_DATA_BLOB pPfx,
            [MarshalAs(UnmanagedType.LPWStr)] string szPassword,
            PfxCertStoreFlags dwFlags);

        [DllImport(CRYPT32, SetLastError = true)]
        public static extern bool CertAddCertificateContextToStore(
            IntPtr hCertStore,
            IntPtr pCertContext,
            CertStoreAddDisposition dwAddDisposition,
            ref IntPtr ppStoreContext
        );

        [DllImport(CRYPT32, SetLastError = true)]
        public static extern IntPtr CertEnumCertificatesInStore(
            IntPtr storeProvider,
            IntPtr prevCertContext
        );

        [DllImport(CRYPT32, SetLastError = true)]
        public static extern bool CertCloseStore(
            IntPtr hCertStore,
            CertStoreCloseDisposition dwFlags
        );

        [DllImport(CRYPT32, CharSet = CharSet.Auto, SetLastError = true)]
        public static extern bool CertGetCertificateContextProperty(
            IntPtr pCertContext,
            uint dwPropId,
            IntPtr pvData,
            ref uint pcbData);

        [DllImport(CRYPT32, EntryPoint = "CertSetCertificateContextProperty", CharSet = CharSet.Auto, SetLastError = true)]
        internal static extern Boolean CertSetCertificateContextProperty(
            IntPtr pCertContext,
            Int32 dwPropId,
            Int32 dwFlags,
            IntPtr pvData);

        public class SafeSecurityDescriptorPtr : SafeHandleZeroOrMinusOneIsInvalid
        {
            private static SafeSecurityDescriptorPtr nullHandle = new SafeSecurityDescriptorPtr();

            private int size = -1;

            public SafeSecurityDescriptorPtr()
                : base(true)
            {
            }

            public SafeSecurityDescriptorPtr(uint size)
                : base(true)
            {
                this.size = (int)size;
                this.SetHandle(Marshal.AllocHGlobal(this.size));
            }

            public SafeSecurityDescriptorPtr(IntPtr handle)
                : base(true)
            {
                this.SetHandle(handle);
            }

            public static SafeSecurityDescriptorPtr Null
            {
                get
                {
                    return nullHandle;
                }
            }

            public IntPtr GetDacl()
            {
                IntPtr pDacl = IntPtr.Zero;
                bool daclPresent = false;
                bool daclDefaulted = false;

                if (!GetSecurityDescriptorDacl(
                    this.handle,
                    out daclPresent,
                    ref pDacl,
                    out daclDefaulted))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                if (!daclPresent)
                {
                    return IntPtr.Zero;
                }
                else
                {
                    return pDacl;
                }
            }

            public byte[] GetBinaryForm()
            {
                if (size < 0)
                {
                    throw new NotSupportedException();
                }

                byte[] buffer = new byte[size];
                Marshal.Copy(this.handle, buffer, 0, buffer.Length);

                return buffer;
            }

            protected override bool ReleaseHandle()
            {
                try
                {
                    Marshal.FreeHGlobal(this.handle);
                    return true;
                }
                catch
                {
                    // semantics of this function are to never throw an exception so we must eat the underlying error and 
                    // return false. 
                    return false;
                }
            }
        }

        public class SafeCryptProviderHandle : SafeHandleZeroOrMinusOneIsInvalid
        {
            private static SafeCryptProviderHandle nullHandle = new SafeCryptProviderHandle();

            public SafeCryptProviderHandle()
                : base(true)
            {
            }

            public SafeCryptProviderHandle(IntPtr handle)
                : base(true)
            {
                this.SetHandle(handle);
            }

            public static SafeCryptProviderHandle Null
            {
                get
                {
                    return nullHandle;
                }
            }

            internal SafeCryptProviderHandle Duplicate()
            {
                if (this.IsInvalid || this.IsClosed)
                {
                    throw new InvalidOperationException();
                }

                // in the window between the call to CryptContextAddRef and when the raw handle value is assigned 
                // into the new safe handle, there's a second reference to the original safe handle that the CLR does 
                // not know about, so we need to bump the reference count around this entire operation to ensure 
                // that we don't have the original handle closed underneath us. 
                bool acquired = false;
                try
                {
                    this.DangerousAddRef(ref acquired);
                    IntPtr underlyingHandle = this.DangerousGetHandle();
                    SafeCryptProviderHandle duplicate = new SafeCryptProviderHandle();
                    int lastError = 0; 
 
                    // atomically add reference and set handle on the duplicate 
                    $PrepareConstrainedRegions
                    try
                    {
                    }
                    finally
                    {
                        if (!CryptContextAddRef(this, IntPtr.Zero, 0))
                        {
                            lastError = Marshal.GetLastWin32Error();
                        }
                        else
                        {
                            duplicate.SetHandle(underlyingHandle);
                        }
                    }

                    if (lastError != 0)
                    {
                        duplicate.Dispose();
                        throw new Win32Exception(lastError);
                    }

                    return duplicate;
                }
                finally
                {
                    if (acquired)
                    {
                        this.DangerousRelease();
                    }
                }
            }

            protected override bool ReleaseHandle()
            {
                return CryptReleaseContext(this.handle, 0);
            }
        }
    }

    public static class PfxHelper
    {
        public static void ImportPfx(string pfxPath, string pfxPassword, StoreLocation storeLocation,
            StoreName storeName, Win.PfxCertStoreFlags pfxCertStoreFlags = Win.PfxCertStoreFlags.None)
        {
            ImportPfx(pfxPath, pfxPassword, storeLocation, Enum.GetName(typeof(StoreName), storeName),
                pfxCertStoreFlags);
        }

        public static void ImportPfx(string pfxPath, string pfxPassword, string storeLocation,
            StoreName storeName, Win.PfxCertStoreFlags pfxCertStoreFlags = Win.PfxCertStoreFlags.None)
        {
            ImportPfx(pfxPath, pfxPassword, storeLocation, Enum.GetName(typeof(StoreName), storeName),
                pfxCertStoreFlags);
        }

        public static void ImportPfx(string pfxPath, string pfxPassword, StoreLocation storeLocation,
            string storeName, Win.PfxCertStoreFlags pfxCertStoreFlags = Win.PfxCertStoreFlags.None)
        {
            Win.StoreLocationFlags storeLocationFlags;

            switch (storeLocation)
            {
                case StoreLocation.CurrentUser:
                    storeLocationFlags = Win.StoreLocationFlags.CERT_SYSTEM_STORE_CURRENT_USER;
                    break;
                case StoreLocation.LocalMachine:
                    storeLocationFlags = Win.StoreLocationFlags.CERT_SYSTEM_STORE_LOCAL_MACHINE;
                    break;
                default:
                    throw new Exception("Unknown store location");
            }

            ImportPfx(pfxPath, pfxPassword, storeLocationFlags, storeName, pfxCertStoreFlags);
        }

        public static void ImportPfx(string pfxPath, string pfxPassword, string storeLocation,
            string storeName, Win.PfxCertStoreFlags pfxCertStoreFlags = Win.PfxCertStoreFlags.None)
        {
            Win.StoreLocationFlags storeLocationFlags;

            switch (storeLocation)
            {
                case "CurrentUser":
                    storeLocationFlags = Win.StoreLocationFlags.CERT_SYSTEM_STORE_CURRENT_USER;
                    break;
                case "LocalMachine":
                    storeLocationFlags = Win.StoreLocationFlags.CERT_SYSTEM_STORE_LOCAL_MACHINE;
                    break;
                default:
                    throw new Exception("Unknown store location");
            }

            ImportPfx(pfxPath, pfxPassword, storeLocationFlags, storeName, pfxCertStoreFlags);
        }

        public static void ImportPfx(string pfxPath, string pfxPassword, Win.StoreLocationFlags storeLocationFlags,
            string storeName, Win.PfxCertStoreFlags pfxCertStoreFlags = Win.PfxCertStoreFlags.None)
        {
            try
            {
                IntPtr hCryptProv = IntPtr.Zero;
                IntPtr hCertStore = Win.CertOpenStore(Win.CertStoreProvider.CERT_STORE_PROV_SYSTEM,
                    0,
                    hCryptProv,
                    storeLocationFlags,
                    storeName);

                if (hCertStore == IntPtr.Zero) return;
                try
                {
                    byte[] rawData = System.IO.File.ReadAllBytes(pfxPath);

                    IntPtr pbData = Marshal.AllocHGlobal(rawData.Length);
                    try
                    {
                        Marshal.Copy(rawData, 0, pbData, rawData.Length);

                        Win.CRYPT_DATA_BLOB ppfx = new Win.CRYPT_DATA_BLOB();
                        ppfx.cbData = rawData.Length;
                        ppfx.pbData = pbData;

                        IntPtr hMemStore = Win.PFXImportCertStore(ref ppfx, pfxPassword, pfxCertStoreFlags);

                        if (hMemStore == IntPtr.Zero) return;
                        try
                        {
                            IntPtr pctx = IntPtr.Zero;
                            IntPtr pStoreContext = IntPtr.Zero;

                            List<string> certificateHashes = new List<string>();

                            while (IntPtr.Zero != (pctx = Win.CertEnumCertificatesInStore(hMemStore, pctx)))
                            {
                                var certificateHash = GetCertificateHash(pctx);
                                certificateHashes.Add(certificateHash);
                            }

                            string lastCertificateHash = certificateHashes.FindLast(x => true);

                            while (IntPtr.Zero != (pctx = Win.CertEnumCertificatesInStore(hMemStore, pctx)))
                            {
                                var certificateHash = GetCertificateHash(pctx);

                                if (certificateHash == lastCertificateHash)
                                {
                                    //We always want to replace the actual certificate
                                    Win.CertAddCertificateContextToStore(hCertStore,
                                        pctx,
                                        Win.CertStoreAddDisposition.CERT_STORE_ADD_REPLACE_EXISTING,
                                        ref pStoreContext);
                                }
                                else
                                {
                                    //If chain is not already added, then we add it
                                    Win.CertAddCertificateContextToStore(hCertStore,
                                        pctx,
                                        Win.CertStoreAddDisposition.CERT_STORE_ADD_USE_EXISTING,
                                        ref pStoreContext);
                                }
                            }
                        }
                        finally
                        {
                            Win.CertCloseStore(hMemStore, Win.CertStoreCloseDisposition.NONE);
                        }
                    }
                    finally
                    {
                        Marshal.FreeHGlobal(pbData);
                    }
                }
                finally
                {
                    Win.CertCloseStore(hCertStore, Win.CertStoreCloseDisposition.NONE);
                }
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
            }
        }

        private static string GetCertificateHash(IntPtr certificatePtr)
        {
            X509Certificate certificate = new X509Certificate(certificatePtr);
            return certificate.GetCertHashString();
        }
    }

    public static class AclHelper
    {
        public static TriageHandle TriageAcquireKeyHandle(X509Certificate2 certificate)
        {
            SafeNCryptKeyHandle ncryptKeyHandle = null;
            Win.SafeCryptProviderHandle cspHandle = null;
            Win.KeySpec keySpec;
            bool ownHandle = true;

            if (!Win.CryptAcquireCertificatePrivateKey(
                certificate.Handle,
                Win.CryptAcquireKeyFlags.CRYPT_ACQUIRE_SILENT_FLAG,
                IntPtr.Zero,
                out cspHandle,
                out keySpec,
                out ownHandle))
            {
                Win32Exception cspException = new Win32Exception(Marshal.GetLastWin32Error());

                if (!Win.CryptAcquireCertificatePrivateKey(
                    certificate.Handle,
                    Win.CryptAcquireNCryptKeyFlags.CRYPT_ACQUIRE_SILENT_FLAG,
                    IntPtr.Zero,
                    out ncryptKeyHandle,
                    out keySpec,
                    out ownHandle))
                {
                    throw new AggregateException(
                        new Win32Exception(Marshal.GetLastWin32Error()),
                        cspException);
                }
            }

            if (!ownHandle)
            {
                throw new NotSupportedException("Must be able to take ownership of the certificate private key handle.");
            }

            if (ncryptKeyHandle != null)
            {
                return new CngTriageHandle(ncryptKeyHandle);
            }
            else if (cspHandle != null)
            {
                if (keySpec != Win.KeySpec.AT_KEYEXCHANGE && keySpec != Win.KeySpec.AT_SIGNATURE)
                {
                    throw new NotSupportedException("Only exchange or signature key pairs are supported.");
                }

                return new CapiTriageHandle(cspHandle);
            }
            else
            {
                throw new NotSupportedException("The certificate private key cannot be accessed.");
            }
        }

        public static void AssertSuccess(this Win.ErrorCode code)
        {
            if (code != Win.ErrorCode.Success)
            {
                throw new Win32Exception((int)code);
            }
        }

        public abstract class TriageHandle : IDisposable
        {
            public TriageHandle()
            {
            }

            public abstract FileSecurity Acl
            {
                get;
                set;
            }

            public abstract bool IsValid
            {
                get;
            }

            public abstract void Dispose();
        }

        public class CapiTriageHandle : TriageHandle
        {
            public CapiTriageHandle(Win.SafeCryptProviderHandle handle) : base()
            {
                this.Handle = handle;
            }

            public override bool IsValid
            {
                get
                {
                    return this.Handle != null && !this.Handle.IsInvalid && !this.Handle.IsClosed;
                }
            }

            public override FileSecurity Acl
            {
                get
                {
                    uint securityDescriptorSize = 0;
                    if (!Win.CryptGetProvParam(
                        this.Handle,
                        Win.ProvParam.PP_KEYSET_SEC_DESCR,
                        Win.SafeSecurityDescriptorPtr.Null,
                        ref securityDescriptorSize,
                        Win.SECURITY_INFORMATION.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }

                    Win.SafeSecurityDescriptorPtr securityDescriptorBuffer = new Win.SafeSecurityDescriptorPtr(securityDescriptorSize);

                    if (!Win.CryptGetProvParam(
                        this.Handle,
                        Win.ProvParam.PP_KEYSET_SEC_DESCR,
                        securityDescriptorBuffer,
                        ref securityDescriptorSize,
                        Win.SECURITY_INFORMATION.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }

                    using (securityDescriptorBuffer)
                    {
                        FileSecurity acl = new FileSecurity();
                        acl.SetSecurityDescriptorBinaryForm(securityDescriptorBuffer.GetBinaryForm());
                        return acl;
                    }
                }

                set
                {
                    if (!Win.CryptSetProvParam(
                        this.Handle,
                        Win.ProvParam.PP_KEYSET_SEC_DESCR,
                        value.GetSecurityDescriptorBinaryForm(),
                        Win.SECURITY_INFORMATION.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }
                }
            }

            protected Win.SafeCryptProviderHandle Handle
            {
                get;
                set;
            }

            public override void Dispose()
            {
                this.Handle.Dispose();
            }
        }

        public class CngTriageHandle : TriageHandle
        {
            public CngTriageHandle(SafeNCryptHandle handle) : base()
            {
                this.Handle = handle;
            }

            public override bool IsValid
            {
                get
                {
                    return this.Handle != null && !this.Handle.IsInvalid && !this.Handle.IsClosed;
                }
            }

            public override FileSecurity Acl
            {
                get
                {
                    uint securityDescriptorSize = 0;
                    Win.NCryptGetProperty(
                        this.Handle,
                        Win.NCRYPT_SECURITY_DESCR_PROPERTY,
                        Win.SafeSecurityDescriptorPtr.Null,
                        0,
                        ref securityDescriptorSize,
                        Win.SECURITY_INFORMATION.DACL_SECURITY_INFORMATION).AssertSuccess();

                    Win.SafeSecurityDescriptorPtr securityDescriptorBuffer = new Win.SafeSecurityDescriptorPtr(securityDescriptorSize);

                    Win.NCryptGetProperty(
                        this.Handle,
                        Win.NCRYPT_SECURITY_DESCR_PROPERTY,
                        securityDescriptorBuffer,
                        securityDescriptorSize,
                        ref securityDescriptorSize,
                        Win.SECURITY_INFORMATION.DACL_SECURITY_INFORMATION).AssertSuccess();

                    using (securityDescriptorBuffer)
                    {
                        FileSecurity acl = new FileSecurity();
                        acl.SetSecurityDescriptorBinaryForm(securityDescriptorBuffer.GetBinaryForm());
                        return acl;
                    }
                }

                set
                {
                    byte[] sd = value.GetSecurityDescriptorBinaryForm();
                    Win.NCryptSetProperty(
                        this.Handle,
                        Win.NCRYPT_SECURITY_DESCR_PROPERTY,
                        sd,
                        (uint)sd.Length,
                        Win.SECURITY_INFORMATION.DACL_SECURITY_INFORMATION).AssertSuccess();
                }
            }

            protected SafeNCryptHandle Handle
            {
                get;
                set;
            }

            public override void Dispose()
            {
                this.Handle.Dispose();
            }
        }
    }
} 
"@

if (-not $global:CryptoCertificateManagementCompiled)
{
    Write-Verbose "Loading certificate management p/invoke shim."
    Add-Type -TypeDefinition $source -Language CSharp -ReferencedAssemblies $references -ErrorAction Stop
    $global:CryptoCertificateManagementCompiled = $true
}
else
{
    Write-Warning "Certificate management class was already loaded. If you made any changes, you will need to close and re-open PowerShell to successfully import the new module."
}


function Add-AccessRule
{
    <# 
    .SYNOPSIS 
    Adds a file access rule to a file security descriptor. 
 
    .DESCRIPTION 
    Accepts a file access rule or constructs a new access rule from the provided parameters and appends it to an existing file security descriptor. Leaves the original security descriptor intact and returns an updated copy. 
 
    .PARAMETER SD 
    An existing file security descriptor. Can be retrieved from certificates by accessing the Acl property. 
 
    .PARAMETER UserAccount 
    A string identifying a user or group principal that will be controled by this access rule. 
 
    .PARAMETER FileSystemRights 
    The rights to be granted to the UserAccount by this access rule. 
 
    .PARAMETER AccessControlType 
    Whether this is an allow or deny access rule. 
 
    .PARAMETER Rule 
    A pre-created file system access rule. 
 
    .EXAMPLE 
    $certificate.Acl = $certificate.Acl | Add-AccessRule "Administrator" FullControl Allow 
 
    Adds a rule granting the local administrator full control of the $certificate's private key. 
 
    .EXAMPLE 
    $sd = Add-AccessRule -UserAccount "Everyone" -FileSystemRights Read -AccessControlType Deny -SD $sd 
 
    Appends a rule to an existing security descriptor ($sd) that denys all users read access. 
    #>
    
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline=$true,Position=3,Mandatory=$true)]
        [ValidateNotNull()]
        [System.Security.AccessControl.FileSecurity] $SD,

        [Parameter(Position=0,Mandatory=$true,ParameterSetName="ctor")]
        [ValidateNotNullOrEmpty()]
        [string] $UserAccount,

        [Parameter(Position=1,Mandatory=$true,ParameterSetName="ctor")]
        [ValidateNotNullOrEmpty()]
        [System.Security.AccessControl.FileSystemRights] $FileSystemRights,

        [Parameter(Position=2,Mandatory=$true,ParameterSetName="ctor")]
        [ValidateNotNullOrEmpty()]
        [System.Security.AccessControl.AccessControlType] $AccessControlType,

        [Parameter(Mandatory=$true,ParameterSetName="obj")]
        [ValidateNotNullOrEmpty()]
        [System.Security.AccessControl.FileSystemAccessRule] $Rule
    )

    if (-not $Rule)
    {
        $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule $UserAccount,$FileSystemRights,$AccessControlType -ErrorAction Stop
    }

    # perform a deep clone of the input SD to prevent side effects
    $newSD = New-Object System.Security.AccessControl.FileSecurity
    $newSD.SetSecurityDescriptorBinaryForm($SD.GetSecurityDescriptorBinaryForm())

    # add the new rule
    $newSD.AddAccessRule($Rule)
    Write-Output $newSD
}    
    EOH
    set_library_script
  end
end
