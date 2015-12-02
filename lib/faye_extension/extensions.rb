require 'faye/extension'
Faye::Extension.load_helpers

module Faye
  class Extension

    # Add timestamps if not exist.
    class AddTimestamp < Faye::Extension
      incoming do
        #unless message['channel'] == '/meta/connect' ##|| message['connectionType'] == 'in-process'
        unless channel[%r{^/meta}]
          add_timestamp
        end
      end

      outgoing do
        #if !(message['channel'] == '/meta/connect') && message['data']
        unless channel[%r{^/meta}]
          add_timestamp
        end
      end

      # TODO: Do we really need 3 levels of timestamp (protocol, message, chat)?
      def add_timestamp
        message['timestamp'] ||= DateTime.now
        if data.is_a?(Hash)
          data['timestamp'] ||= message['timestamp']
          if data['action'] == "chat" &&  data['data'].is_a?(Hash)
            data['data']['timestamp'] ||= message['timestamp']
          end
        end
        #puts "ADD_TIMESTAMP self #{self} message #{message}"
      end
    end # AddTimestamp

    # Add extension to log message info.
    class LogMessageInfo < Faye::Extension
      class << self; attr_accessor :last_server; end
      def_delegators self, :last_server, :'last_server='
      
      incoming do #|message, request, callback|
        unless channel == '/meta/connect' ##|| message['connectionType'] == 'in-process'
          self.last_server = [message, request, callback] if request
          puts ["#{request.env['REMOTE_ADDR'] rescue 'SERVER'}", "MESSAGE (incoming): #{channel}", "REQUEST: #{request.object_id}"].join('; ')
        end
      end
    end

    # Block non-chat non-meta messages.
    # BUG: Faye bug - adding 'error' to a message will NOT prevent further extension processing!!!
    #      You have to do this yourself (see Extension class).
    class Whitelist < Faye::Extension
      incoming do
        if
          !request ||  # TODO: find a better way to determine if this msg originated on server.
          channel =~ /^\/meta/ ||
          data['action'] == 'chat'
        then
          # All is good
        else
          message['error'] = "403::Forbidden Only chat messages can be published to other clients"
          puts "WHITELIST FAIL: #{message}"
        end
      end
    end

    # Handle private client-server messages.
    class HandlePrivateMessage < Faye::Extension
      incoming do #|message, request, callback|
        if channel == '/meta/private' &&  client_guid
          message['channel'] = '/private'
          #puts "SERVER RECEIVING PRIVATE MESSAGE FOR #{client_guid}"
          #resp = App.new.call(request.env.merge("PATH_INFO" => message['data']['action']))
          resp = App.new.call(request.env.merge("PATH_INFO" => '/test'))
          #faye_client.publish("/#{client_guid}", {action: "chat", data: [message['data']['data'], (request), resp[2]].join(', ') })
          faye_client.publish("/#{client_guid}", { 'action' => "chat", 'data' => data['data'] })
        end
      end
    end

    # Track recent chat messages.
    class TrackRecentMessages < Faye::Extension
      incoming do #|message, request, callback|
        if !channel[%r{/meta}] && data['action'] == 'chat' && request
          #puts "STORING RECENT MESSAGE #{message['data']}"
          redis_client.rpush "/recent#{channel}", message.to_yaml
          redis_client.ltrim("/recent#{channel}", -5, -1)
        end
      end
    end

    # Send recent chat messages upon subscription.
    class SendRecentMessages < Faye::Extension
      incoming do #|message, request, callback|
        # First get the callback out of the way, then process recent messages.
        callback.call(message)
        @callback = nil
        if channel[%r{/meta/subscribe}] && request && client_id
          #puts "SendRecentMessages#incoming #{client_id} is subscribing to #{message['subscription']}"

          # For some reason the subscriptions are not active yet without
          # using threading here. Is this extension somehow blocking
          # faye from updating redis?
          Thread.new do
            begin
              sleep 1 # required to allow subscription to complete first.
              #puts "SendRecentMessages new thread SLEPT FOR 1 SEC"        

              # This bypass will force push all subscriptions it can find, on each new subscription run.
              #subscriptions = [client_subscriptions(client_id), [message['subscription']] ].flatten
        
              # Only send recent messages if this is the private subscription,
              # or if the private subscription already exists (and this is not it).
              subscriptions = case
                # TODO: This condition should probably be removed.
                # Private-channel subscription should always be the first to load from client side. 
                when nil && is_subscribing_to_private_channel
                  # send recent messages from all previously subscribed channels.
                  #puts "SendRecentMessages#incoming #{client_id} is subscribing to private channel #{client_guid}\n"
                  client_subscriptions
                when has_private_subscription
                  # send recent messages from this currently subscribed channel
                  #puts "SendRecentMessages#incoming #{client_id} has private channel #{client_guid}"
                  [subscription]
                else
                  #puts "SendRecentMessages#incoming #{client_id} has no private channel yet on #{client_guid}"
              end
    
              if subscriptions
                #puts "SendRecentMessages#incoming sending recent messages for subscriptions #{subscriptions}"
                channels = channels_matching_subscriptions(subscriptions, '/recent')
                # messages_as_yaml = channels.map{|ch| redis_client.lrange(ch, -5, -1)}.flatten
                # messages = messages_as_yaml.map{|msg| YAML.load(msg)['data']}
                messages = get_messages(channels, -5, -1, [:[], 'data'])
                
                if messages.any?
                  EM.next_tick do  # This prevents a locking condition when using Puma.
                    faye_client.publish("/#{client_guid}", {'action' => "chat", 'data' => messages })
                  end
                end
                
              end # if
            rescue
              puts "ERROR: SendRecentMessages Thread #{$!}\n"
            end
          end # thread
    
        end # if
      end # incoming
    end # SendRecentMessages
    
    
    # Experimental auto-subscript of private client-server channel.
    # Also see companion functions in extension js.
    class SubscribePrivate < Faye::Extension
      incoming do
        #puts "SubscribePrivate#incoming #{message.object_id}"
        if channel == '/meta/subscribe' && subscription == '/private/server'
          message['subscription'] = "/#{client_guid}"
        end
      end

      # TODO: This is flawed in that it requires us to use clientId as the private channel subscription.
      # We should not rely on clientId to do this... but how?
      # Trying to fix with 'client_guid'.
      outgoing do
        #puts "SubscribePrivate#outgoing #{message.object_id}"
        if channel == '/meta/subscribe' && subscription == "/#{client_guid}"
          #puts "SubscribePrivate#outgoing message before: #{message.inspect}"
         ext["private_subscription_response"] = true
          #puts "SubscribePrivate#outgoing message after: #{message.inspect}"
        end
      end
    end
    
    # # Helpful for debugging.
    # class EndOfChain < Faye::Extension
    #   incoming do
    #     puts "END-OF-CHAIN-INCOMING #{message}"
    #   end
    #   outgoing do
    #     puts "END-OF-CHAIN-OUTGOING #{message}"
    #   end
    # end
    
  end # Extension
end # Faye




