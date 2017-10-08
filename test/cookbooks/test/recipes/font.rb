windows_font 'CodeNewRoman.otf'

cookbook_file 'C:/Asimov.otf' do
  source 'Asimov.otf'
end

# specify a source, but make it local
windows_font 'Asimov.otf' do
  source 'C:/Asimov.otf'
end

# make sure we can handle backslashes in a local path
windows_font 'Asimov.otf' do
  source 'C:\Asimov.otf'
end
