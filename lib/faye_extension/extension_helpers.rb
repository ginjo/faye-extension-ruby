module FayeExtension
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
    
  end # Helpers
end # FayeExtension