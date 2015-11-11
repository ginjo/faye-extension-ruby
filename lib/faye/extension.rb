require 'faye'
require File.expand_path('../rack_adapter', __FILE__)
require 'forwardable'

module Faye

  class Extension
    extend Forwardable
    
    class << self
      attr_accessor :faye_server, :faye_client, :redis_client, :children
    end
    
    @children = []
    
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
    
    def self.inherited(child)
      @children << child
    end
  
  end # Extension
  
end # Faye