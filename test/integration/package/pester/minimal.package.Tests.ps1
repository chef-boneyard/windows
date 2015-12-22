$global:progressPreference = 'SilentlyContinue'

describe 'minimal::package' {
  context 'minimal_package' {

    it "task 'task_for_system' was created"  {
      Test-Path "C:\Program Files\Mercurial\hg.exe" | Should Be True
    }
  }
}

