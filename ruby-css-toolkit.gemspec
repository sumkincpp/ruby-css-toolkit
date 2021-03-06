Gem::Specification.new do |s|
  s.name    = 'css_toolkit'
  s.version = '1.4'
  s.email   = "rhulse@paradise.net.nz"
  s.author  = "Richard Hulse"

  s.description = %q{Provides some tools to minify and compress CSS files - Ruby ports of the YUI CSS Compressor and CSS Tidy}
  s.summary     = %q{CSS minification}
  s.homepage    = %q{http://github.com/rhulse/ruby-css-toolkit}

  s.files = Dir['lib/**/*']
  s.require_path = 'lib'
end