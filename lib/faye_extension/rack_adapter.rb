require 'faye'
require 'faye/adapters/rack_adapter'
require 'faye_extension/static_server'

# TODO: Move static_server_array stuff into extension_helpers... Hmm, maybe not.

module Faye
  class RackAdapter
    alias_method :initialize_original, :initialize
  
    def initialize(*args)
      initialize_original(*args)
      Faye::Extension.setup(self)
      load_custom_static_server
      self
    end
    
    def load_custom_static_server
      custom_static = StaticServer.new(File.expand_path('../../faye_extension', __FILE__), /(?:extension\.js(\.erb)?)$/)
      custom_static.map('extension.js', 'faye_extension_helper.js.erb')
      @static = StaticServerArray.new << custom_static << @static
      #puts "STATIC-SERVER-ARRAY"
      #puts @static.to_yaml
    end
    
    def get_binding
      binding
    end
  
  end
end