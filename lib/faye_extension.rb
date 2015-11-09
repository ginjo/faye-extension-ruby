require 'faye'
require 'redis'
require "faye_extension/version"
require "faye_extension/extensions"


class Faye::RackAdapter
  alias_method :initialize_original, :initialize
  
  def initialize(*args)
    initialize_original(*args)
    Faye::Extension.faye_server = self
    Faye::Extension.faye_client = get_client
    Faye::Extension.descendants.each{|d| puts "Faye::RackAdapter adding extension #{d.name}"; add_extension(d.new)}
    Faye::Extension.redis_client = Redis.new #:host=>'localhost', :port=>6379
    EM.next_tick do
      Faye::Extension.faye_client.publish('/foo', {action: "Server", text: 'A new faye server in-process client is online', timestamp:DateTime.now})
    end
  end
  
end


def get_recent_messages
  y Faye::Extension.new.instance_eval{ get_messages(channels_matching_subscriptions(['/**']), 0, -1) }
end
  
  
class FayeExtension
  # attr_accessor :next_app, :args, :faye
  # 
  # send :define_method, :initialize do |next_app, *args|
  #   @next_app = next_app
  #   @args = args
  #   @faye = Faye::RackAdapter.new next_app, :mount => '/fayeserver', :timeout => 25, :engine => {
  #     :type  => Faye::Redis,
  #     #:host  => 'localhost',
  #     #:port  => '6379',
  #     # more options
  #   }
  #   
  #   puts "USING FAYE MIDDLEWARE"
  # 
  #   # Create faye client from in-process server client.
  #   # This client cannot subscribe (you should use an extension for that).
  #   # Hmm, I think that's wrong... this client CAN subscribe.
  #   #::FAYE_CLIENT = faye.get_client
  # 
  #   Faye::Extension.descendants.reverse.each{|d| faye.add_extension(d.new)}
  #   
  #   yield(faye) if block_given?
  # 
  #   # EM.next_tick do
  #   #   FAYE_CLIENT.publish('/foo', {action: "Server", text: 'A new faye server in-process client is online', timestamp:DateTime.now})
  #   # end
  # end # new
  # 
  #   
  # def call(env)
  #   faye.call(env)
  #   #next_app.call(env)
  # end
  # 
  # #::REDIS_CLIENT = Redis.new #:host=>'localhost', :port=>6379
  
  
  
  # Launch full faye pub/sub server.
  # Note that you can use curl to publish to faye:
  # curl -X POST http://localhost:9292/fayeserver -H 'Content-Type: application/json' -d '{"channel": "/foo", "data": {"text":"Some text", "action":"jackson"}}'
  # use Faye::RackAdapter, :mount => '/fayeserver', :timeout => 25, :engine => {
  #   :type  => Faye::Redis,
  #   #:host  => 'localhost',
  #   #:port  => '6379',
  #   # more options
  # } do |faye|
  #   puts "USING FAYE MIDDLEWARE"
  #   
  #   # Create faye client from in-process server client.
  #   # This client cannot subscribe (you should use an extension for that).
  #   # Hmm, I think that's wrong... this client CAN subscribe.
  #   ::FAYE_CLIENT = faye.get_client
  #   
  #   Faye::Extension.descendants.reverse.each{|d| faye.add_extension(d.new)}
  #   
  #   EM.next_tick do
  #     FAYE_CLIENT.publish('/foo', {action: "Server", text: 'A new faye server in-process client is online', timestamp:DateTime.now})
  #   end
  # end # use
    
end # FayeExtension
  
