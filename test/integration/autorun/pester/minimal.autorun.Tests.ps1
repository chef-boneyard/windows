$global:progressPreference = 'SilentlyContinue'

describe 'test::autorun' {
  context 'windows_auto_run' {
    it "does not auto-run Notepad for the machine" {
      $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
      (Get-ItemProperty -Path $path).notepad | Should Be $Null
    }

    it "auto-runs Wordpad for the current user" {
      $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
      (Get-ItemProperty -Path $path).wordpad | Should Be '"C:\Windows\System32\write.exe" '
    }
  }
}
