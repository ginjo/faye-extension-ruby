require 'faye'
require 'faye/adapters/rack_adapter'
require 'faye_extension/static_server'

# TODO: Move static_server_array stuff into extension_helpers... Hmm, maybe not.

module Faye
  class RackAdapter
    
    attr_reader :app, :options, :endpoint, :extensions, :endpoint_re, :server, :static, :client
    
    alias_method :initialize_original, :initialize
  
    def initialize(*args)
      initialize_original(*args)
      Faye::Extension.setup(self)
      @static = StaticServerArray.new(@static, File.expand_path('../../faye_extension', __FILE__), /(?:extension\.js(\.erb)?)$/)
      @static[0].map('extension.js', 'faye_extension_helper.js.erb')
      store_faye_in_main_app
      self
    end
    
    def store_faye_in_main_app
      faye = self
      @app.instance_eval do
        @faye = faye
        define_singleton_method(:faye){ @faye }
      end
    end
    
    def get_binding
      binding
    end
      
  end
end