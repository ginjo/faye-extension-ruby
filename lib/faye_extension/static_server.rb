require 'erb'

module Faye
  
  class StaticServer
    
    # Intercept the File.read method to process thru erb, if applicable.
    class File < ::File
      def self.read(path)
        #puts "FILE.READ path: #{path}"
        if File.extname(path) == '.erb'
          begin
            ERB.new(super(path)).result(Extension.faye_server.get_binding)
          rescue
            puts "Faye Extension ERB error: #{$!}"
            raise $!
          end
        else
          super(path)
        end
      end
    end # File

  end # StaticServer


  # Array of Faye StaticServer objects,
  # so we can add some static files to
  # to be available from the Faye server.
  class StaticServerArray < Array
    
    # Build new instance from existing static-server plus new static-server.
    def initialize(existing_static, *params_for_new_static)
      custom_static = StaticServer.new(*params_for_new_static)
      self << custom_static << existing_static
      #puts "NEW-STATIC-SERVER-ARRAY #{self}"
      self
    end
    
    def call(env)
      static_server = (self =~ (env['PATH_INFO']))
      if static_server.respond_to?(:call)
        #puts "STATIC-SERVER-ARRAY#call static_server: #{static_server.inspect}"
        static_server.call(env)
      else
        [404, {}, []]
      end
    end
    
    # Call 'map' on each StaticServer.
    def map(*args)
      each {|x| x.map(*args)}
    end
    
    # Call '=~' on StaticServer that matches path.
    def =~(path)
      #puts "STATIC-SERVER-ARRAY#=~ path: #{path.inspect}"
      detect {|x| x =~ path}
    end
  end # StaticServerArray
  
end # Fay