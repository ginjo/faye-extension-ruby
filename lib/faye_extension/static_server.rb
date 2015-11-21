require 'erb'

module Faye
  
  class StaticServer
    
    # Intercept the File.read method to process thru erb, if appropriate.
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
  # Or not so static files, processed by erb.
  class StaticServerArray < Array
    def call(env)
      static_server = (self =~ (env['PATH_INFO']))
      if static_server.respond_to?(:call)
        #puts "STATIC-SERVER-ARRAY#call static_server: #{static_server.inspect}"
        static_server.call(env)
      else
        [404, {}, []]
      end
    end
    
    def map(*args)
      each {|x| x.map(*args)}
    end
    
    def =~(path)
      #puts "STATIC-SERVER-ARRAY#=~ path: #{path.inspect}"
      detect {|x| x =~ path}
    end  
  end # StaticServerArray
  
end # Fay