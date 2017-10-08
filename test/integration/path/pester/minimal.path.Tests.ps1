$global:progressPreference = 'SilentlyContinue'

describe 'test::path' {
  context 'windows_path' {
    $SystemVariables  = get-itemproperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    $UserVariables = get-itemproperty 'HKCU:\Environment'

    $Paths = ($SystemVariables.path -split ';')

    it "'C:\path_test_path' was added to the path" {
      ($Paths -contains 'C:\path_test_path') | should be $true
    }

    it "'c:\path_test_with_forward_slashes' was added to the path" {
      ($Paths -contains 'C:\path_test_with_forward_slashes') | should be $true
    }

    it "'C:\path_test_path' was added to the path" {
      ($Paths -contains 'C:\path_test_path') | should be $true
    }

    it 'Child processes and shellouts have an updated path' {
      'c:\paths.txt' | should FileContentMatch 'C:\\path_test_another_path'
      'c:\paths.txt' | should FileContentMatch 'C:\\path_test_path'
    }

    it 'Updates the path for new external processes' {
      'c:\external_paths.txt' | should FileContentMatch 'C:\\path_test_another_path'
      'c:\external_paths.txt' | should FileContentMatch 'C:\\path_test_path'
    }
  }
}
