# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'faye_extension/version'

Gem::Specification.new do |spec|
  spec.name          = "faye-extension"
  spec.version       = Faye::Extension::VERSION
  spec.authors       = ["William Richardson"]
  spec.email         = ["wbr@mac.com"]
  spec.summary       = %q{Adds an Extension class to help construct Faye server extensions.}
  spec.description   = %q{Adds an Extension class to help construct Faye server extensions. Enhances Faye::Extension with optional helpers to facilitate pub/sub, private messaging, rpc, and data updates in the context of your Rack App.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  
  spec.add_dependency "faye"
  spec.add_dependency "redis"
  spec.add_dependency "faye-redis"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
end

