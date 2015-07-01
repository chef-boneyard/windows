$global:progressPreference = 'SilentlyContinue'

describe 'minimal::default' {
  context 'windows_certificate' {

    it "installs der-cert1"  {
      "Cert:\LocalMachine\My\47beabc922eae80e78783462a79f45c254fde68b" | Should Exist
    }

    it "installs and removes base64-cert2" {
      "Cert:\LocalMachine\My\47beabc922eae80e78783462a79f45c254fde68b" | Should Not Exist
    }

    it "installs and removes test-cert" {
      "Cert:\LocalMachine\My\‎‎5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6" | Should Exist
    }

    it "puts persists the private key for test-cert" {
      $cert = Get-ChildItem Cert:\LocalMachine\My\‎‎5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6
      $cert.PrivateKey.CspKeyContainerInfo.MachineKeyStore | Should Be True
      $uniqueName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
      "$Env:ProgramData\Microsoft\Crypto\RSA\MachineKeys\$uniqueName" | Should Exist
    }
  }
}

