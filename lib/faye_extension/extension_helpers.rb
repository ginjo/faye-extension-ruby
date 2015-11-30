require 'faye/extension'
require 'net/http'
require 'redis'
require 'json'

# TODO: Figure out how to handle the hardcoded URLs below ('http://localhost:9292/fayeserver').
# TODO: The message format may not be quite right. Don't get the message format confused with the
#       function arguments format. You might want to use :ext as a 3rd catch-all key in messages,
#       to carry info that is not part of the function call.

# Examples
#   # View messages.
#   Faye::Extension.redis_client.lrange('/recent/foo/bar', 0, -1).each{|m| puts m}; nil
#   # Show all keys.
#   puts Faye::Extension.redis_client.keys
#   # Delete a key.
#   puts Faye::Extension.redis_client.del('/recent/foo/bar')
#   

module Faye
  class Extension
  
    def client_subscriptions
      subscriptions = redis_client.smembers "/clients/#{client_id}/channels"
      #puts "CLIENT SUBSCRIPTIONS for \"/clients/#{client_id}/channels\" #{subscriptions}\n"
      subscriptions
    rescue
      puts "ERROR FayeExtension#client_subscriptions #{$!}"
    end

    def has_private_subscription
      redis_client.exists("/channels/#{client_guid}")
    rescue
      puts "ERROR FayeExtension#has_private_subscription #{$!}"
    end

    def is_subscribing_to_private_channel
      #puts "FayeExtension::Helpers#is_subscribing_to_private_channel CHANNEL: #{message['channel']} SUBSCRPT: #{message['subscription']} CLIENTID: #{client_guid}"
      message['channel'] == '/meta/subscribe' &&
      (message['subscription'] =~ Regexp.new(client_guid) || message['subscription'] =~ Regexp.new(client_id) || message['subscription'] == '/private/server') &&
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
    # TODO: This method may be too specific to finding /recent/<subscription> messages
    def get_messages(channels, range1, range2, restrict=nil)
      #puts "FayExtension#get_messages for channels: #{channels}"
      messages_as_yaml = channels.map{|ch| redis_client.lrange(ch, range1, range2)}.flatten
      messages = messages_as_yaml.map do |msg|
        raw = YAML.load(msg)
        # This is to ignore legacy messages with no timestamp
        next unless raw['data'] && raw['data']['timestamp'] && raw['data']['data']
        (restrict ? raw.send(*restrict) : raw)['data']     
      end.compact #.sort{|a,b| (a['data']['timestamp'] <=> b['data']['timestamp']) rescue 0}
    end

    def self.get_recent_messages
      y new.instance_eval{ get_messages(channels_matching_subscriptions(['/**'], '/recent'), 0, -1) }
    end   
    
    
    # TODO: Consider moving these to main app.
    
    # Temporary redis client, to be overwritten with options from faye, once faye starts.
    # This is only really useful for testing.
    @redis_client = ::Redis.new

    # Top-level method publish to faye with net-http.
    def self.publish_http_message(channel, data, ext={})
      message = {:channel => channel, :data => data, :ext => ext}
      uri = URI.parse("http://localhost:9292/fayeserver")
      Net::HTTP.post_form(uri, :message => message.to_json)
    end

    # Top-level method publish to faye with EM faye-client.
    def self.publish_message(channel, data, ext={})
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
  
  end # Extension
end # Faye

