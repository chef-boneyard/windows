$global:progressPreference = 'SilentlyContinue'

describe 'test::http_acl' {
  context 'minimal_http_acl' {

    it "http_acl added for some user to access google.com"  {
      netsh http show urlacl url=http://google.com:80/ | Out-String | Should match "space user"
    }
  }
}
