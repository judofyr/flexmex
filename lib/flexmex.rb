require 'flexmex_ext'

module Flexmex
  module Constants
    include Align
    include Display
    include Edge
    include FlexDirection
    include FlexWrap
    include Direction
    include Overflow
  end
end

require 'flexmex/node'
require 'flexmex/box'
require 'flexmex/terminal'
require 'flexmex/color'

module Flexmex
  def self.mount(*args)
    MainTerminal.mount(*args)
  end
end

