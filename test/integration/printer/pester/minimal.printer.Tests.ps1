$global:ProgressPreference = 'SilentlyContinue'

Describe 'test::printer' {
  context 'windows_printer' {
    it 'printer driver installed' {
      Get-PrinterDriver 'HP Color LaserJet 1600 Class Driver'
    }
    
    it 'printer port installed' {
      Get-PrinterPort '192.168.100.100'
    }

    it 'printer installed' {
      Get-Printer 'HP Color LaserJet 1600'
    }
  }
}