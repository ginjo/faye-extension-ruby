# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'faye_extension/version'

Gem::Specification.new do |spec|
  spec.name          = "faye-extension"
  spec.version       = Faye::Extension::VERSION
  spec.authors       = ["wbr"]
  spec.email         = ["wbr@mac.com"]
  spec.summary       = %q{Adds an Extension class to help construct Faye server extensions.}
  spec.description   = %q{Enhances Faye with Faye::Extension class, with optional helpers, to help construction of server-side extensions.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_dependency "faye" #, "~> 1.1"
  spec.add_dependency "redis" #, "~> 3.2"
  spec.add_dependency "faye-redis" #, "~> 0.2

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
