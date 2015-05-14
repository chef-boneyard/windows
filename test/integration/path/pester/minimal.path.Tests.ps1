$global:progressPreference = 'SilentlyContinue'



describe 'minimal::default' {
  context 'windows_path' {
    $SystemVariables  = get-itemproperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    $UserVariables = get-itemproperty 'HKCU:\Environment'

    $Paths = ($SystemVariables.path -split ';')

    it "'C:\path_test_path' was added to the path" {
      ($Paths -contains 'C:\path_test_path') | should be $true
    }

    it "'C:\path_test_another_path' was added to the path" {
      ($Paths -contains 'C:\path_test_another_path') | should be $true
    }
  }
}