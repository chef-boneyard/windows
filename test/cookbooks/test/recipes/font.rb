windows_font 'CodeNewRoman.otf'

cookbook_file 'C:/Asimov.otf' do
  source 'Asimov.otf'
end

windows_font 'Asimov.otf' do
  source 'C:/Asimov.otf'
end

windows_font 'Local Asimov with forward slashes' do
  font_name 'Asimov.otf'
  source 'C:\Asimov.otf'
end

windows_font 'Local Asimov with double forward slashes' do
  font_name 'Asimov.otf'
  source 'C:\\Asimov.otf'
end
