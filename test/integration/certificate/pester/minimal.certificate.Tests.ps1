$global:progressPreference = 'SilentlyContinue'

describe 'test::certificate' {
  context 'windows_certificate' {

    it "installs der-cert1"  {
      "Cert:\LocalMachine\My\47BEABC922EAE80E78783462A79F45C254FDE68B" | Should Exist
    }

    it "installs and removes base64-cert2" {
      "Cert:\LocalMachine\My\2796BAE63F1801E277261BA0D77770028F20EEE4" | Should Not Exist
    }

    it "installs test-cert" {
      "Cert:\LocalMachine\CA\5081F667F1EF005D0EC39FA3E30AA71B4FD84EB6" | Should Exist
    }

    it "puts persists the private key for test-cert" {
      $cert = Get-ChildItem "Cert:\LocalMachine\CA\5081F667F1EF005D0EC39FA3E30AA71B4FD84EB6"
      $cert.PrivateKey.CspKeyContainerInfo.MachineKeyStore | Should Be True
      $uniqueName = $cert.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
      "$Env:ProgramData\Microsoft\Crypto\RSA\MachineKeys\$uniqueName" | Should Exist
    }

    it "binds test-cert to port 443" {
      $binding = netsh http show sslcert ipport=0.0.0.0:443
      $binding[4] | Should Match ' : 0.0.0.0:443\s*$'
      $binding[5] | Should Match ' : 5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6$'
    }

    it "binds test-cert to port 444 with custom app-id" {
      $binding = netsh http show sslcert ipport=0.0.0.0:444
      $binding[4] | Should Match ' : 0.0.0.0:444\s*$'
      $binding[5] | Should Match ' : 5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6$'
      $binding[6] | Should Match ' : {00000000-0000-0000-0000-000000000000}\s*$'
    }

    it "binds test-cert to port 443 with host www.chef.io" {
      $binding = netsh http show sslcert hostnameport=www.chef.io:443
      $binding[4] | Should Match ' : www.chef.io:443\s*$'
      $binding[5] | Should Match ' : 5081f667f1ef005d0ec39fa3e30aa71b4fd84eb6$'
    }
  }
}
