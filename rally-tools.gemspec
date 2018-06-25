lib = File.expand_path('../lib/', __FILE__)

Gem::Specification.new do |s|
  s.name        = 'rally-tools'
  s.version     = '1.0.0'
  s.date        = '2018-06-19'
  s.summary     = "Tools for developing workflows with SDVI Rally"
  s.description = "Tools for developing workflows with SDVI Rally"
  s.authors     = ["Neil Kempin"]
  s.email       = 'neilkempin@gmail.com'
  s.files       = Dir.glob("{bin,lib}/**/*")
  s.executables = ['rally-tools-cli']
  s.homepage    =
    'https://github.com/cornelius-k/Rally-Tools'
  s.license       = 'MIT'
end
