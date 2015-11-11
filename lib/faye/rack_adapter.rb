class Faye::RackAdapter
  alias_method :initialize_original, :initialize
  
  def initialize(*args)
    initialize_original(*args)
    Faye::Extension.faye_server = self
    Faye::Extension.faye_client = get_client
    Faye::Extension.children.each{|d| puts "Faye::RackAdapter adding extension #{d.name}"; add_extension(d.new)}
    # TODO: pass args to redis client instantiation.
    Faye::Extension.redis_client = Redis.new #:host=>'localhost', :port=>6379
  end
  
end