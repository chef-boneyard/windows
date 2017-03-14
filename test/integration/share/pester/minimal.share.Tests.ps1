$global:progressPreference = 'SilentlyContinue'

describe 'minimal::share' {
    context 'windows_share' {
        it "creates share read_only"  {
            "\\localhost\read_only" | Should Exist
        }
    
        it "sets description"  {
            $s = Get-WmiObject win32_share -filter 'Name like "read_only"'
            $s.description | Should Match "a test share"
        }
    
        it "permissions read_only to prevent write"  {
            $f = New-Item "\\localhost\read_only\bang" -Type File -ErrorAction SilentlyContinue
            $f | Should BeNullOrEmpty
        }
    
        it "creates share change"  {
            "\\localhost\change" | Should Exist
        }
    
        $fileName = "\\localhost\change\change_file"
        it "permissions change to allow create"  {
            $f = New-Item $fileName -Type File 
            $f.Name | Should Be "change_file"
        }
    
        it "permissions change to allow delete"  {
            Remove-Item $fileName
        }
    
        it "creates share full"  {
            "\\localhost\full" | Should Exist
        }
    
        $fileName = "\\localhost\full\change_file"
        it "permissions full to allow create"  {
            $f = New-Item $fileName -Type File 
            $f.Name | Should Be "change_file"
        }
    
        it "permissions full to allow delete"  {
            Remove-Item $fileName
        }
    
        it "removes share no_share"  {
            "\\localhost\no_share" | Should Not Exist
        }
    
        it "can change the directory associated with a share"  {
            $s = Get-WmiObject win32_share -filter 'Name like "changed_dir"'
            $s.path | Should Match "c:/test_share"
        }
    
    }
}
