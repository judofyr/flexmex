module Flexmex
  class InputHandler
    def initialize(app)
      @app = app
    end

    ESCAPE_MAPPING = {
      "A" => :up,
      "B" => :down,
      "C" => :right,
      "D" => :left,
    }

    KEY_MAPPING = {
      "\n" => :enter,
      "\e" => :escape,
      "\x7F" => :backspace,
    }

    def call(str)
      chars = str.each_char

      loop do
        char = chars.next
        if char == "\e"
          begin
            char = chars.next
            if char == "["
              char = chars.next
              char = ESCAPE_MAPPING.fetch(char, char)
            end
          rescue StopIteration
          end
        end

        char = KEY_MAPPING.fetch(char, char)
        emit(char)
      end
    end

    def emit(key)
      @app.handle_key(key)
    end
  end
end

