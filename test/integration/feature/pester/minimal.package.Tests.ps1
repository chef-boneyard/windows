$global:progressPreference = 'SilentlyContinue'

describe 'test::feature' {
  context 'minimal_feature' {

    it "feature TelnetClient installed using dism"  {
      Get-Command Telnet -ErrorAction SilentlyContinue | Should Not Be $Null
    }

    it "feature TFTP Client installed using powershell"  {
      Get-Command tftp -ErrorAction SilentlyContinue | Should Not Be $Null
    }

    it "feature Web-Ftp-Server and sub features installed using powershell" {
      (Get-WindowsFeature Web-Ftp-* | ?{$_.InstallState -eq "Installed"}).count | Should Be 3
    }

    it "feature Web-Asp-Net45 and Web-Net-Ext45 installed using powershell" {
      (Get-WindowsFeature Web-Asp-Net45,Web-Net-Ext45 | ?{$_.InstallState -eq "Installed"}).count | Should Be 2
    }
  }
}
