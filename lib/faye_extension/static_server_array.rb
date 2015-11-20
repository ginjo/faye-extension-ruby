# Array of Faye StaticServer objects,
# so we can add some static files to
# to be available from the Faye server.
module Faye
  class StaticServerArray < Array
    def call(env)
      #puts "STATIC-SERVER-ARRAY#call last_match: #{@last_match.inspect}"
      @last_match.call(env) if @last_match.respond_to?(:call)
    end
    
    def map(*args)
      each {|x| x.map(*args)}
    end
    
    def =~(rgxp)
      #puts "STATIC-SERVER-ARRAY#=~ regexp: #{rgxp.inspect}"
      @last_match = detect {|x| x =~ rgxp}
    end  
    
  end
end