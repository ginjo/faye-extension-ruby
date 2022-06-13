# faye-extension-ruby

Adds an Extension class to help construct Faye server extensions. Enhances Faye::Extension with optional helpers to facilitate pub/sub, private messaging, rpc, and data updates in the context of your Rack App.

This gem is currently in experimental stage.

This gem assumes your are using Redis as your Faye backend datastore (engine).


## Installation

Gemfile:

    gem 'faye-extension'

No Gemfile:

    $ gem install faye-extension

## Usage

    require 'faye/extension'

Then, before faye-server starts up, create your server extensions.

    class MyFayeServerExtension < Faye::Extension

      incoming do
        puts [message, request, callback].to_yaml
      end

      outgoing do
        # outgoing code here
      end
      
      def added
        ...
      end

      def removed
        ...
      end
      
    end

Extension classes will be automatically added to Faye, when Faye server starts.

```message```, ```request```, and ```callback``` are presented as instance variables (with accessors),
and will be propagated thru the extension chain as expected.

Exceptions will add to ```message['error']``` and will not bubble up to the surface. The non-nil existence of ```message['error']```will block further Faye::Extension instances from processing. However Faye server will continue to handle these messages and message['error'] as expected. Set ```IGNORE_MESSAGE_ERRORS = TRUE``` on your extension class (or on Faye::Extension) to allow extensions to process messages that have ```message['error']``` defined.

Additional helpers exist for accessing message attributes in the context of an extension instance.

TODO: Expand this section.

    client_id
    ext
    error
    channel
    subscription
    data

    # Overwrite this with your own guid getter, if you prefer.
    def client_guid
      client_id
    end    

