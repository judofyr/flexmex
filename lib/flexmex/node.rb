module Flexmex
  class Node
  end

  class BoxNode < Node
    attr_accessor :border_color
    attr_accessor :background_color
    attr_accessor :inverse
    attr_accessor :offset_x
    attr_accessor :offset_y

    class BoxPropBuilder
      def initialize(klass)
        @klass = klass
        edge("margin")
        edge("padding")
        edge("border")
        enum("align_items")
        enum("align_self")
        enum("justify_content")
        enum("flex_direction")
        enum("flex_wrap")
        enum("overflow")
        float("flex")
        float("flex_grow")
        float("flex_shrink")
        float("max_height")
        float("max_width")
      end

      def def_setter(name, code)
        Array(name).each do |name|
          @klass.class_eval "def #{name}=(value); #{code} end"
        end
      end

      EDGES = {
        "left" => Edge::Left,
        "top" => Edge::Top,
        "right" => Edge::Right,
        "bottom" => Edge::Bottom,
        "start" => Edge::Start,
        "end" => Edge::End,
        "horizontal" => Edge::Horizontal,
        "vertical" => Edge::Vertical,
        "" => Edge::All,
      }

      def edge(name)
        EDGES.each do |post, edge|
          fullname = post.empty? ? name : "#{name}_#{post}"
          shortname = name[0] + (post[0] || "")
          def_setter([fullname, shortname], "set_#{name}(#{edge}, value.to_f)")
          def_setter([fullname+"_percent", shortname+"_pct"], "set_#{name}_percent(#{edge}, value.to_f)")
        end
      end

      def float(name)
        def_setter(name, "set_#{name}(value.to_f)")
      end

      def enum(name)
        def_setter(name, "set_#{name}(value)")
      end
    end

    BoxPropBuilder.new(self)

    def initialize
      @offset_x = 0
      @offset_y = 0
    end

    def draw_into(rect)
      width = rect.width
      height = rect.height

      bt = get_border_layout(Edge::Top).to_i
      bb = get_border_layout(Edge::Bottom).to_i
      bl = get_border_layout(Edge::Left).to_i
      br = get_border_layout(Edge::Right).to_i

      ## Step 1: Background color (inside border)
      bg = background_color
      inv = inverse
      if bg || inv
        (width-bl-br).times do |dx|
          (height-bt-bb).times do |dy|
            px, py = dx+bl, dy+bt
            rect.at(px, py) do |tile|
              tile.style.background = bg
              tile.style.inverse = inv
            end
          end
        end
      end

      ## Step 2: Borders

      # TODO: Support border-width > 1?
      color = border_color

      set_border = proc do |dx, dy, content|
        rect.at(dx, dy) do |tile|
          tile.content = content
          tile.style.foreground = color
          tile.style.background = bg
        end
      end

      if bl > 0
        (height-2).times do |dy|
          set_border.call(0, dy + 1, :border_v)
        end

        if bt > 0
          set_border.call(0, 0, :border_tl)
        end

        if bb > 0
          set_border.call(0, height - 1, :border_bl)
        end
      end

      if br > 0
        (height-2).times do |dy|
          set_border.call(width - 1, dy + 1, :border_v)
        end

        set_border.call(width - 1, 0, :border_tr)
        set_border.call(width - 1, height - 1, :border_br)
      end

      if bt > 0
        (width-2).times do |dx|
          set_border.call(dx + 1, 0, :border_h)
        end
      end

      if bb > 0
        (width-2).times do |dx|
          set_border.call(dx + 1, 0 + height - 1, :border_h)
        end
      end
    end
  end

  class TextNode < Node
    attr_accessor :content, :text_overflow, :bold

    def initialize(content = "")
      @content = content
      @text_overflow = :clip
      enable_measure
    end

    def content=(content)
      mark_dirty if content != @content
      @content = content
    end

    def measure(width, height)
      if width.nil? or width == 0
        [@content.size, 1]
      else
        height = (@content.size / width).ceil
        if height == 1
          width = @content.size
        end
        [width, height]
      end
    end

    def draw_into(rect)
      width = rect.width
      height = rect.height
      dy = 0
      dx = 0

      # TODO: Handle widths correctly
      # TODO: Implement smarter word-wrapping
      # TODO: Handle newlines

      @content.each_char.with_index do |char, idx|
        char = " " if char == "\n"

        if dx >= width
          if dy < height - 1
            dx = 0
            dy += 1
          else
            if @text_overflow == :ellipsis
              rect.at(dx-1, dy) do |t|
                t.content = "\u2026"
              end
            end
            break
          end
        end

        rect.at(dx, dy) do |t|
          t.content = char
          t.style.bold = bold
        end

        dx += 1
      end
    end
  end
end

