require 'faye'
require File.expand_path('../../faye_extension/rack_adapter', __FILE__)
require 'forwardable'


# NOTE: Design subscription logic so that any channel can get any message.
# Channels should only be used to route messages, not to provide processing logic.
# Use a MessageHandler class in js to process all incoming messages.


module Faye
  class Extension
    extend Forwardable
    @children = []
  
    class << self
      attr_reader :faye_server, :faye_client, :redis_client, :children
    end

    def_delegators self, :faye_server, :faye_client, :redis_client
  
    attr_accessor :message, :request, :callback
  
  
    # Take a block and yield it inside an instance :incoming method,
    # with the usual arguments (message, request, callback).
    # The base :incoming method will handle callback & errors,
    # so you just supply the custom code with 'incoming do |message,request,callback| block'
    def self.incoming(&block)
      @incoming_proc = block
      self.send :define_method, :incoming do |message, request, callback|
        begin
          return callback.call(message) if callback.respond_to?(:call) && message['error']
          message['ext'] ||= {}
          message['ext']['incoming_chain'] ||= []
          message['ext']['incoming_chain'] << self.class.name
        
          # The ghost is necessary (it's really an instance of this instance)
          # so that each message run can have it's own inst vars,
          # and the inst vars are necessary so the block in the instance_eval
          # can have access to message, request, and callback.
          # (Remember that instance_eval doesn't work with local method vars).
          ghost = self.dup
          ghost.message = message
          ghost.request = request
          ghost.callback = callback
          ghost.instance_eval &block #&incoming_proc
          ghost.callback.call(ghost.message) if ghost.callback.respond_to?(:call)
        rescue
          message['error'] = "ERROR: faye extension #{self.class.name} (incoming) failed with: #{$!}"
          puts message['error']
          callback.call(message) if callback.respond_to?(:call)
        end # begin/rescue/end
      end # define_method
    end # self.incoming
  
    def self.outgoing(&block)
      @outgoing_proc = block
      self.send :define_method, :outgoing do |message, request, callback|
        begin
          message['ext'] ||= {}
          message['ext']['outgoing_chain'] ||= []
          message['ext']['outgoing_chain'] << self.class.name
          
          ghost = self.dup
          ghost.message = message
          ghost.request = request
          ghost.callback = callback
          ghost.instance_eval &block #&outgoing_proc
          ghost.callback.call(ghost.message) if ghost.callback.respond_to?(:call)
        rescue
          message['error'] = "ERROR: faye extension #{self.class.name} (outgoing) failed with: #{$!}"
          puts message['error']
          callback.call(message) if callback.respond_to?(:call)
        end # begin/resuce/end
      end # define_method
    end # self.outgoing
    
    def added(*args)
      puts "Faye::RackAdapter adding extension #{self.class.name}";
    end
    
    def removed(*args)
      puts "Faye::RackAdapter removing extension #{self.class.name}";
    end
    
    # Shortcut to clientId.
    def client_id
      message['clientId']
    end
    
    # Overwrite this with your own guid getter (and setter), if you prefer.
    def client_guid
      client_id
    end
    
    def ext
      message['ext']
    end
    
    def error
      message['error']
    end
    
    def channel
      message['channel']
    end
    
    def subscription
      message['subscription']
    end
    
    def data
      message['data']
    end
    
    def self.inherited(child)
      @children << child
    end
    
    def self.register_extensions(adapter)
      children.each{|d| adapter.add_extension(d.new)}
    end
    
    # Setup faye extension class from new Faye::RackAdapter
    def self.setup(adapter)
      @faye_server = adapter
      @faye_client = adapter.get_client
      register_extensions(adapter)
      set_redis_client
      # TODO: For dev only, remove before publishing to public.
      EM.next_tick do
        faye_client.publish('/foo', {'action' => "chat", 'data' => {'channel' => '/foo', 'text' => 'A new faye server in-process client is online', 'timestamp' => DateTime.now}})
      end
    end
    
    def self.set_redis_client
      return unless @faye_server
      faye_engine_options = @faye_server.options[:engine]
      redis_options = faye_engine_options[:type].name=="Faye::Redis" ? faye_engine_options : {}
      @redis_client = ::Redis.new redis_options
    end
    
    def self.load_helpers
      require 'faye_extension/extension_helpers'
    end
    
    def self.load_extensions
      require 'faye_extension/extensions'
    end
  
  end # Extension
  
end # Faye