require 'faye'
require 'faye/adapters/rack_adapter'
require 'faye_extension/static_server_array'

module Faye
  class RackAdapter
    alias_method :initialize_original, :initialize
  
    def initialize(*args)
      initialize_original(*args)
      Faye::Extension.setup(self)
      custom_static = StaticServer.new(File.expand_path('../../faye_extension', __FILE__), /(?:extension\.js)$/)
      custom_static.map('extension.js', 'faye-extension.js')
      @static = StaticServerArray.new << custom_static << @static
      #puts "STATIC-SERVER-ARRAY"
      #puts @static.to_yaml
      self
    end
  
  end
end