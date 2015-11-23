# FayeExtension

Adds an Extension class to help construct Faye server extensions. Enhances Faye and Faye::Extension with optional helpers to facilitate pub/sub, private messaging, rpc, and data updates in the context of your Rack App.


## Installation

Add this line to your application's Gemfile:

    gem 'faye-extension'


And then execute:

    $ bundle

Or install it yourself as:

    $ gem install faye-extension

## Usage

    class MyFayeServerExtension < Faye::Extension

      # Mini-dsl to build 'incoming' method
      incoming do
        # Put your 'incoming' method here.
        # message, request, and callback are all presented as instance variables,
        # and will be propagated thru the extension chain as expected.
        # Exceptions will abort current extension, but will not disrupt further extension processing.
      end
      
      # Same as above for outgoing.
      
      # Optionally define you own 'added' and 'removed' methods.
      
      # Extension classes will be automatically added to Faye, when Faye server starts.
      
    end

