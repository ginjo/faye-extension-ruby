require 'faye'
require 'redis'
require "faye_extension/version"
require 'faye/extension'
require "faye_extension/extension_helpers"

Faye::Extension.send :include, FayeExtension::Helpers

require "faye_extension/extensions"
  
  
module FayeExtension

end # FayeExtension
  
# For testing
def get_recent_messages
  y Faye::Extension.new.instance_eval{ get_messages(channels_matching_subscriptions(['/**']), 0, -1) }
end

EM.next_tick do
  Faye::Extension.faye_client.publish('/foo', {action: "Server", text: 'A new faye server in-process client is online', timestamp:DateTime.now})
end