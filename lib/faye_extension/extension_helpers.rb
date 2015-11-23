require 'faye/extension'
require 'net/http'
require 'redis'
require 'json'

# TODO: Figure out how to handle the hardcoded URLs below ('http://localhost:9292/fayeserver').

module Faye
  class Extension
    module Helpers
    
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
        #puts "FayeExtension::Helpers#is_subscribing_to_private_channel CHANNEL: #{message['channel']} SUBSCRPT: #{message['subscription']} CLIENTID: #{message['clientId']}"
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
      
      def self.included(parent)
        # TODO: Figure out how to get redis connection params from faye, before faye starts up..
        #puts "NEW_REDIS_CLIENT for parent #{parent.inspect}"
        #puts [parent.faye_server.options.inspect]
        parent.instance_variable_set(:@redis_client, ::Redis.new) #:host=>'localhost', :port=>6379
      end
    
    end # Helpers
  end # Extension
end # Faye

# Top-level method publish to faye with net-http.
def faye_publish_http_message(channel, data, ext={})
  message = {:channel => channel, :data => data, :ext => ext}
  uri = URI.parse("http://localhost:9292/fayeserver")
  Net::HTTP.post_form(uri, :message => message.to_json)
end

# Top-level method publish to faye with EM faye-client.
def faye_publish_message(channel, data, ext={})
  EM.run do
    client = Faye::Client.new('http://localhost:9292/fayeserver')
    publication = client.publish(channel, data, ext)
    publication.callback do
      #puts "[PUBLISH SUCCEEDED]"
      EM.stop_event_loop
      return publication
    end
    publication.errback do |error|
      puts "[PUBLISH FAILED] #{error.inspect}"
      EM.stop_event_loop
      return error
    end
  end
end

def faye_get_recent_messages
  y Faye::Extension.new.instance_eval{ get_messages(channels_matching_subscriptions(['/**']), 0, -1) }
end

