module Flexmex
  class Color
    names = %w[black red green yellow blue magenta cyan white]
    
    names.each_with_index do |name, idx|
      class_eval <<-EOF, __FILE__, __LINE__
        def self.#{name}
          @#{name} ||= new(#{idx})
        end
      EOF
    end

    def initialize(idx)
      @idx = idx
    end

    def to_foreground
      @foreground ||= "#{30+@idx}"
    end

    def to_background
      @background ||= "#{40+@idx}"
    end
  end

  RGB = Struct.new(:r, :g, :b) do
    SCALE = ["00", "5F", "87", "AF", "D7", "FF"].map(&:hex)

    MAPPING = Hash.new do |h, k|
      # TODO: Use the scale-values somehow
      idx = k * SCALE.size / 255
      h[k] = idx
    end

    MAPPING[0] = 0

    # TODO: Return 256-colors?

    def to_foreground
      "38;2;#{r};#{g};#{b}"
    end

    def to_background
      "48;2;#{r};#{g};#{b}"
    end
  end
end

