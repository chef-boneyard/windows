include_recipe 'windows::default'

windows_font 'CodeNewRoman.otf'

cookbook_file 'C:/Asimov.otf' do
  source 'Asimov.otf'
end

windows_font 'Asimov.otf' do
  source 'C:/Asimov.otf'
end
