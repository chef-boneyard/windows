$global:progressPreference = 'SilentlyContinue'

describe 'minimal::feature' {
  context 'minimal_feature' {

    it "feature TelnetClient was created"  {
      Get-Command Telnet -ErrorAction SilentlyContinue | Should Not Be $Null
    }
  }
}
