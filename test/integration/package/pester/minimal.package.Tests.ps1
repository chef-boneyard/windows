$global:progressPreference = 'SilentlyContinue'

describe 'test::package' {
  context 'test_package' {

    it "task 'task_for_system' was created"  {
      Test-Path "C:\Program Files\Mercurial\hg.exe" | Should Be True
    }
  }
}

