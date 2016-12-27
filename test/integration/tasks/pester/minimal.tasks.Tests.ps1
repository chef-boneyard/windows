$global:progressPreference = 'SilentlyContinue'

describe 'test::tasks' {
  context 'windows_task' {
    [xml]$top_level_task = schtasks /query /tn 'task_from_name' /XML 2> $null
    [xml]$second_level_task_no_leading_slash = schtasks /query /tn '\chef\nested task' /XML 2> $null
    [xml]$second_level_task_leading_slash = schtasks /query /tn '\chef\longtask' /XML 2> $null
    $second_level_task = schtasks /query /tn '\chef\longtask' /FO csv /v | convertfrom-csv 2> $null
    [xml]$missing_task = schtasks /query /tn 'delete_me' /XML 2> $null
    [xml]$task_changed_by_create = schtasks /query /tn '\chef\change_me' /XML 2> $null
    [xml]$system_task = schtasks /query /tn 'task_for_system' /XML 2> $null
    [xml]$task_on_idle = schtasks /query /tn 'task_on_idle' /XML 2> $null

    it "task 'task_from_name' was created"  {
      $top_level_task | Should Not BeNullOrEmpty
    }

    it "task 'task_from_name' was disabled" {
      [bool]::parse($top_level_task.task.Settings.Enabled) |
        Should Be $false
    }

    it "task 'task_from_name' has command set to dir" {
      $top_level_task.Task.Actions.Exec.Command | Should Be 'dir'
    }

    it "task 'chef\nested task' was created (no leading \)" {
      $second_level_task_no_leading_slash | Should Not BeNullOrEmpty
    }

    it "task 'chef\nested task' was changed to command 'dir /s" {
      $Command = $second_level_task_no_leading_slash.Task.Actions.Exec.Command
      $second_level_task_no_leading_slash.Task.Actions.Exec.Arguments |
        foreach {$Command += " $_"}
      $Command | Should Be 'dir /s'
    }

    it 'task \chef\longtask was created (with leading \)' {
      $second_level_task_leading_slash | Should Not BeNullOrEmpty
    }

    it 'task \chef\longtask was started and stopped' {
      $second_level_task.'Last Run Time' | Should Not Match 'N/A'
    }

    it 'task \chef\longtask was started and stopped and is ready' {
      $second_level_task.'Status' | Should Be 'Ready'
    }

    it 'task delete_me should not exist' {
      $missing_task | Should BeNullOrEmpty
    }

    it "task 'chef\change_me' was changed via create to command 'dir /s" {
      $Command = $task_changed_by_create.Task.Actions.Exec.Command
      $task_changed_by_create.Task.Actions.Exec.Arguments |
        foreach {$Command += " $_"}
      $Command | Should Be 'dir /s'
    }

    it "task 'task_for_system' was created"  {
      $system_task | Should Not BeNullOrEmpty
    }

    it "task 'task_for_system' runs in temp"  {
      $system_task.Task.Actions.Exec.WorkingDirectory | Should Be $env:temp
    }

    it "task 'task_on_idle' was created"  {
      $task_on_idle | Should Not BeNullOrEmpty
    }

    it "task 'task_on_idle' has IdleTrigger"  {
      $task_on_idle.Task.Triggers.IdleTrigger | Should Not BeNullOrEmpty
    }

    it "task 'task_on_idle' has IdleSetting duration 30 minutes"  {
      $task_on_idle.Task.Settings.IdleSettings.Duration | Should be 'PT30M'
    }

    it 'notifies other resources' {
      test-path 'c:/notifytest.txt' | should be $true
    }
  }
}

