require 'faye/extension'

# Outgoing ext to add timestamp if not exist.
class AddTimestamp < Faye::Extension
  incoming do
    #unless message['channel'] == '/meta/connect' ##|| message['connectionType'] == 'in-process'
    unless message['channel'][%r{^/meta}]
      add_timestamp(message)
    end
  end
  
  outgoing do
    #if !(message['channel'] == '/meta/connect') && message['data']
    unless message['channel'][%r{^/meta}]
      add_timestamp(message)
    end
  end
  
  def add_timestamp(message)
    message['timestamp'] ||= DateTime.now
    if message['data']
      message['data']['timestamp'] ||= message['timestamp']
    end
    #puts "ADD_TIMESTAMP self #{self} message #{message}"
  end
end

# Add extension to log message info.
class LogMessageInfo < Faye::Extension
  incoming do #|message, request, callback|
    unless message['channel'] == '/meta/connect' ##|| message['connectionType'] == 'in-process'
      puts ["#{request.env['REMOTE_ADDR'] rescue 'SERVER'}", "MESSAGE (incoming): #{message}", "REQUEST: #{request.object_id}"].join('; ')
    end
  end
end

# Add extension to intercept private client-server messages.
# Note that execptions (all?) in an extension will not bubble up to surface.
# Instead, they will cause the message to fail... and retry over & over in some cases.
class InterceptPrivateMessage < Faye::Extension
  incoming do #|message, request, callback|
    if message['channel'] == '/meta/private' && message['data'] && (message['data']['client_key'] || message['clientId'])
      uuid = message['data']['client_key'] || message['clientId']
      #puts "SERVER RECEIVING PRIVATE MESSAGE FOR #{uuid}"
      resp = App.new.call(request.env.merge("PATH_INFO" => message['data']['action']))
      faye_client.publish("/#{uuid}", {action: "response", text: [message['data']['text'], (request), resp[2]].join(', ') })
      #message['channel'] = "/#{message['data']['client_key']}"
      #message['data'] = {action: "response", text: [message['text'], (context.request rescue context), resp[2]].join(', ') }
    end
  end
end
  
# Add extension to track recent messages.
class TrackRecentMessages < Faye::Extension
  incoming do #|message, request, callback|
    if !message['channel'][%r{/meta}] && request
      puts "STORING RECENT MESSAGE #{message['data']}"
      redis_client.rpush "/recent#{message['channel']}", message.to_yaml
      redis_client.ltrim("/recent#{message['channel']}", -5, -1)
    end
  end
end

# Add extension to send recent messages upon subscription.
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
          #puts "SLEPT FOR 1 SEC"        

          # This bypass will force push all subscriptions it can find, on each new subscription run.
          #subscriptions = [client_subscriptions(client_id), [message['subscription']] ].flatten
          
          # Only send recent messages if this is the private subscription,
          # or if the private subscription already exists (and this is not it).
          subscriptions = case
            when is_subscribing_to_private_channel(client_id)
              # send recent messages from all previously subscribed channels.
              #puts "SendRecentMessages#incoming #{client_id} is subscribing to private channel"
              client_subscriptions(client_id)
            when has_private_subscription(client_id)
              # send recent messages from this currently subscribed channel
              #puts "SendRecentMessages#incoming #{client_id} has private channel"
              [message['subscription']]
            else
              #puts "SendRecentMessages#incoming #{client_id} has no subscriptions"
          end
      
          if subscriptions
            #puts "SendRecentMessages#incoming has subscriptions #{subscriptions}"
            channels = channels_matching_subscriptions(subscriptions, '/recent')
            # messages_as_yaml = channels.map{|ch| redis_client.lrange(ch, -5, -1)}.flatten
            # messages = messages_as_yaml.map{|msg| YAML.load(msg)['data']}
            messages = get_messages(channels, -5, -1, [:[], 'data'])
      

            faye_client.publish("/#{client_id}", {action: "add", data: messages })
          end # if
        rescue
          puts "ERROR: SendRecentMessages Thread #{$!}\n"
        end
      end # thread
      
    end
  end
end