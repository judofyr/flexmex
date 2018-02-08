$LOAD_PATH << __dir__ + '/../lib'

require 'flexmex'

include Flexmex
include Flexmex::Constants

class App
  def view
    Box.new do |b|
      b.box do |b|
        b.flex_direction = Row

        b.text "Hello",
          border: 1,
          padding: 1

        b.text "Flex",
          border: 1,
          flex: 1

        b.text "Box",
          padding: 1,
          border_right: 1
      end

      b.box(flex: 1, border: 1) do |b|
        b.text "Body"
      end
    end
  end
end

Flexmex.mount(App.new)

