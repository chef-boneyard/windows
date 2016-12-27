$global:progressPreference = 'SilentlyContinue'

describe 'minimal::share' {
  context 'windows_share' {
    it "creates share read_only"  {
      "\\localhost\read_only" | Should Exist
    }
    
    it "sets description"  {
      $s = net share | Out-String
      $s | Should Match "read_only\s*c:\\test_share\s*a test share"
    }
    
    it "permisisons read_only to prevent write"  {
      $f = New-Item "\\localhost\read_only\bang" -Type File
      $f | Should BeNullOrEmpty
    }
    
    it "creates share change"  {
      "\\localhost\change" | Should Exist
    }
    
    $fileName = "\\localhost\change\change_file"
    it "permisisons change to allow create"  {
      $f = New-Item $fileName -Type File 
      $f.Name | Should Be "change_file"
    }
    
    it "permisisons change to allow delete"  {
      Remove-Item $fileName
    }
    
    it "creates share full"  {
      "\\localhost\full" | Should Exist
    }
    
    $fileName = "\\localhost\full\change_file"
    it "permisisons full to allow create"  {
      $f = New-Item $fileName -Type File 
      $f.Name | Should Be "change_file"
    }
    
    it "permisisons full to allow delete"  {
      Remove-Item $fileName
    }
    
    it "removes share no_share"  {
      "\\localhost\no_share" | Should Not Exist
    }
    
    it "can change the directory associated with a share"  {
      $s = net share | Out-String
      $s | Should Match "changed_dir\s*c:\\test_share"
    }
    
  }
}
