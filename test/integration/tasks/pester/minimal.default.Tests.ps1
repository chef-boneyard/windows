$global:progressPreference = 'SilentlyContinue'

describe 'File' {
  context 'c:/chef' {
    it 'is a directory' {
      (get-item 'c:/chef').PSIsContainer | should be $true
    }
  }
}