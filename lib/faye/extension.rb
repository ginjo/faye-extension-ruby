require 'faye'
require 'forwardable'

module Faye

  class Extension
    extend Forwardable
    
    class << self
      attr_accessor :faye_server, :faye_client, :redis_client
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
        ghost = self.dup
        ghost.message = message
        ghost.request = request
        ghost.callback = callback
        ghost.instance_eval &block #&incoming_proc
        ghost.callback.call(ghost.message) if ghost.callback.respond_to?(:call)
      rescue
        puts "ERROR: faye extension #{self.class.name} (incoming) failed with: #{$!}"
        callback.call(message) if callback.respond_to?(:call)
      ensure
        # callback.call(message) if callback.respond_to?(:call)
      end # begin/rescue/end
      end # define_method
    end # self.incoming
  
    def self.outgoing(&block)
      @outgoing_proc = block
      self.send :define_method, :outgoing do |message, request, callback|
      begin 
        ghost = self.dup
        ghost.message = message
        ghost.request = request
        ghost.callback = callback
        ghost.instance_eval &block #&outgoing_proc
        ghost.callback.call(ghost.message) if ghost.callback.respond_to?(:call)
      rescue
        puts "ERROR: faye extension #{self.class.name} (outgoing) failed with: #{$!}"
        callback.call(message) if callback.respond_to?(:call)
      ensure
        #callback.call(message)
      end # begin/resuce/end
      end # define_method
    end # self.outgoing


    def self.descendants
      ObjectSpace.each_object(singleton_class).select {|klass| klass < self }.reverse
    end
  
    def client_subscriptions(client_id)
      subscriptions = redis_client.smembers "/clients/#{client_id}/channels"
      #puts "CLIENT SUBSCRIPTIONS for \"/clients/#{client_id}/channels\" #{subscriptions}\n"
      subscriptions
    rescue
      puts "ERROR FayeExtension#client_subscriptions #{$!}"
    end
  
    def has_private_subscription(client_id)
      redis_client.exists("/channels/#{client_id}")
    rescue
      puts "ERROR FayeExtension#has_private_subscription #{$!}"
    end
  
    def is_subscribing_to_private_channel(message)
      message['channel'] == '/meta/subscribe' &&
      message['subscription'] =~ Regexp.new(message['clientId']) &&
      true
    rescue
      puts "ERROR FayeExtension#is_subscribing_to_private_channel #{$!}"
    end
  
    def channels_matching_subscriptions(subscriptions, prefix='')
      subscriptions.map do |sub|
        redis_client.scan(0, :match=>"#{prefix}#{sub}", :count=>20)[1]
      end.flatten
    rescue
      puts "ERROR FayeExtension#channels_matching_subscriptions #{$!}"
    end
  
    # Get messages from store in redis.
    # This method may be too specific to finding /recent/<subscription> messages
    def get_messages(channels, range1, range2, restrict=nil)
      #puts "FayExtension#get_messages for channels: #{channels}"
      messages_as_yaml = channels.map{|ch| redis_client.lrange(ch, range1, range2)}.flatten
      messages = messages_as_yaml.map do |msg|
        raw = YAML.load(msg)
        # This is to ignore legacy messages with no timestamp
        next unless raw['data'] && raw['data']['timestamp'] #||= nil
        restrict ? raw.send(*restrict) : raw        
      end.compact #.sort{|a,b| (a['data']['timestamp'] <=> b['data']['timestamp']) rescue 0}
    end
  
  end # Extension
  
end # Faye