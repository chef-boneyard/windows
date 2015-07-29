$global:progressPreference = 'SilentlyContinue'

describe 'minimal::package' {
  context 'minimal_package' {

    it "task 'task_for_system' was created"  {
      Test-Path "C:\Program Files (x86)\Mozilla Firefox\firefox.exe" | Should Be True
    }
  }
}

