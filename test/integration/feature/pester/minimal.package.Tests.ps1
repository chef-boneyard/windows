$global:progressPreference = 'SilentlyContinue'

describe 'test::feature' {
  context 'minimal_feature' {

    it "feature TelnetClient was created"  {
      Get-Command Telnet -ErrorAction SilentlyContinue | Should Not Be $Null
    }

    it "feature TFTP Client was created"  {
      Get-Command tftp -ErrorAction SilentlyContinue | Should Not Be $Null
    }

    it "feature ASP.NET 4.5 was created"  {
      Get-WindowsFeature -Name Web-Asp-Net45 | Select Installed | Should Be $True
    }
  }
}
