$global:progressPreference = 'SilentlyContinue'

describe 'minimal::font' {
  context 'windows_font' {

    it "installs CodeNewRoman"  {
      "c:/windows/fonts/CodeNewRoman.otf" | Should Exist
    }
  }
}
