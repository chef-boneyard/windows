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
    [xml]$top_level_task = schtasks /query /tn 'chef test' /XML
    [xml]$second_level_task_no_leading_slash = schtasks /query /tn '\chef\chef test' /XML
    [xml]$second_level_task_leading_slash = schtasks /query /tn '\chef\longtask' /XML
    $second_level_task = schtasks /query /tn '\chef\longtask' /FO csv /v | convertfrom-csv
    [xml]$missing_task = schtasks /query /tn 'delete_me' /XML

    it "task 'chef test' was created"  {
      $top_level_task | Should Not BeNullOrEmpty
    }

    it "task 'chef test' was disabled" {
      [bool]::parse($top_level_task.task.Settings.Enabled) |
        Should Be $false
    }

    it "task 'chef test' has command set to dir" {
      $top_level_task.Task.Actions.Exec.Command | should be 'dir'
    }

    it 'task chef\chef test was created (no leading \)' {
      $second_level_task_no_leading_slash | Should Not BeNullOrEmpty
    }

    it 'task \chef\longtask was created (with leading \)' {
      $second_level_task_leading_slash | Should Not BeNullOrEmpty
    }

    it 'task \chef\longtask was started and stopped' {
      $second_level_task.'Last Run Time' | should Not Match 'N/A'
    }

    it 'task \chef\longtask was started and stopped and is ready' {
      $second_level_task.'Status' | should Be 'Ready'
    }

    it 'task delete_me should not exist' {
      $missing_task | should BeNullOrEmpty
    }
  }
}

