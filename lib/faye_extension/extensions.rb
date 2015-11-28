require 'faye/extension'
Faye::Extension.load_helpers

module Faye
  class Extension

    # Outgoing ext to add timestamp if not exist.
    class AddTimestamp < Faye::Extension
      incoming do
        #unless message['channel'] == '/meta/connect' ##|| message['connectionType'] == 'in-process'
        unless message['channel'][%r{^/meta}]
          add_timestamp
        end
      end

      outgoing do
        #if !(message['channel'] == '/meta/connect') && message['data']
        unless message['channel'][%r{^/meta}]
          add_timestamp
        end
      end

      # TODO: Do we really need 3 levels of timestamp (protocol, message, chat)?
      def add_timestamp
        message['timestamp'] ||= DateTime.now
        if message['data'].is_a?(Hash)
          message['data']['timestamp'] ||= message['timestamp']
          if message['data']['action'] == "chat" &&  message['data']['data'].is_a?(Hash)
            message['data']['data']['timestamp'] ||= message['timestamp']
          end
        end
        #puts "ADD_TIMESTAMP self #{self} message #{message}"
      end
    end

    # Add extension to log message info.
    class LogMessageInfo < Faye::Extension
      incoming do #|message, request, callback|
        unless message['channel'] == '/meta/connect' ##|| message['connectionType'] == 'in-process'
          puts ["#{request.env['REMOTE_ADDR'] rescue 'SERVER'}", "MESSAGE (incoming): #{message['channel']}", "REQUEST: #{request.object_id}"].join('; ')
        end
      end
    end

    # Add extension to intercept private client-server messages.
    # Note that execptions (all?) in an extension will not bubble up to surface.
    # Instead, they will cause the message to fail... and retry over & over in some cases.
    class HandlePrivateMessage < Faye::Extension
      incoming do #|message, request, callback|
        if message['channel'] == '/meta/private' &&  message['clientId']
          uuid = message['clientId']
          #puts "SERVER RECEIVING PRIVATE MESSAGE FOR #{uuid}"
          #resp = App.new.call(request.env.merge("PATH_INFO" => message['data']['action']))
          resp = App.new.call(request.env.merge("PATH_INFO" => '/test'))
          #faye_client.publish("/#{uuid}", {action: "chat", data: [message['data']['data'], (request), resp[2]].join(', ') })
          faye_client.publish("/#{uuid}", { action:"chat", data:message['data']['data'] })
        end
      end
    end

    # Add extension to track recent messages.
    class TrackRecentMessages < Faye::Extension
      incoming do #|message, request, callback|
        if !message['channel'][%r{/meta}] && request
          #puts "STORING RECENT MESSAGE #{message['data']}"
          redis_client.rpush "/recent#{message['channel']}", message.to_yaml
          redis_client.ltrim("/recent#{message['channel']}", -5, -1)
        end
      end
    end

    # BUG: This doesn't work since refactoring message format.
    # Add extension to send recent messages upon subscription.
    # TODO: The private server subscription should be the first one subscribed on the client side,
    # otherwise we get confused as to how to handle feedback from regular subscriptions...
    # There always needs to be a private feedback channel: the private-client-server subscription.
    class SendRecentMessages < Faye::Extension
      incoming do #|message, request, callback|
        callback.call(message)
        @callback = nil
        client_id = message['clientId']
        if message['channel'][%r{/meta/subscribe}] && request && client_id
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
                when nil && is_subscribing_to_private_channel(message)
                  # send recent messages from all previously subscribed channels.
                  #puts "SendRecentMessages#incoming #{client_id} is subscribing to private channel\n"
                  client_subscriptions(client_id)
                when has_private_subscription(client_id)
                  # send recent messages from this currently subscribed channel
                  #puts "SendRecentMessages#incoming #{client_id} has private channel"
                  [message['subscription']]
                else
                  #puts "SendRecentMessages#incoming #{client_id} has no private channel yet"
              end
    
              if subscriptions
                #puts "SendRecentMessages#incoming sending recent messages for subscriptions #{subscriptions}"
                channels = channels_matching_subscriptions(subscriptions, '/recent')
                # messages_as_yaml = channels.map{|ch| redis_client.lrange(ch, -5, -1)}.flatten
                # messages = messages_as_yaml.map{|msg| YAML.load(msg)['data']}
                messages = get_messages(channels, -5, -1, [:[], 'data'])
            
                EM.next_tick do  # This prevents a locking condition when using Puma.
                  faye_client.publish("/#{client_id}", {action:"chat", data:messages })
                end
              end # if
            rescue
              puts "ERROR: SendRecentMessages Thread #{$!}\n"
            end
          end # thread
    
        end # if
      end # incoming
    end # SendRecentMessages
    
  end # Extension
end # Faye




# # Experimental auto-subscript of private client-server channel.
# # Doesn't work, but the problem is js client has no way to alter subscription after success.
# class SubscribePrivate < Faye::Extension
#   incoming do
#     if message['channel'] == '/meta/subscribe' && message['subscription'] == '/private/server'
#       message['subscription'] = "/#{message['clientId']}"
#       message['ext'] = '/private/server'
#     end
#   end
#   
#   outgoing do
#     if message['channel'] == '/meta/subscribe' #&& message['ext'] == '/private/server'
#       puts "SubscribePrivate#outgoing message before: #{message.inspect}"
#       message['ext'] = "/private/server#{message['subscription']}"
#       message['subscription'] = "/private/server"
#       puts "SubscribePrivate#outgoing message after: #{message.inspect}"
#     end
#   end
# end

