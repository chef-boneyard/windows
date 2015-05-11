$global:progressPreference = 'SilentlyContinue'
describe 'File' {
  context 'c:/chef' {
    it 'is a directory' {
      (get-item 'c:/chef').PSIsContainer | should be $true
    }
  }
}

describe 'minimal::default' {
  context 'windows_task' {
    it "task 'chef test' was created"  {
      (schtasks /query /TN 'chef test')[4] |
        should match '^chef\stest'
    }
    it "task 'chef test' was disabled" {
      (schtasks /query /TN 'chef test')[4] |
        should match '^chef\stest\s+.*\s+Disabled.*$'
    }
  }
  context 'windows_path' {
    it "added 'C:\path_test_path' to the path" {
      $env:path | should match ([regex]::escape('C:\path_test_path'))
    }
  }

}

