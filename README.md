# faye-extension-ruby

Adds an Extension class to help construct Faye server extensions. Enhances Faye and Faye::Extension with optional helpers to facilitate pub/sub, private messaging, rpc, and data updates in the context of your Rack App.

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

```message```, ```request```, and ```callback``` are presented as instance variables (with accessors),
and will be propagated thru the extension chain as expected.

Exceptions will abort current extension, but will not disrupt further extension processing.

Extension classes will be automatically added to Faye, when Faye server starts.

