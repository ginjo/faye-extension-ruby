require 'faye'
require 'faye/adapters/rack_adapter'

class Faye::RackAdapter
  alias_method :initialize_original, :initialize
  
  def initialize(*args)
    initialize_original(*args)
    Faye::Extension.setup(self)
  end
  
end