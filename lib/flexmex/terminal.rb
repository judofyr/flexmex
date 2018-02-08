require 'io/console'
require 'termios'
require 'flexmex/input_handler'

module Flexmex
  class TileStyle
    attr_accessor :foreground, :background, :inverse, :bold

    def to_code
      commands = [0]
      if @foreground
        commands << @foreground.to_foreground
      end
      if @background
        commands << @background.to_background
      end
      if @bold
        commands << 1
      end
      if @inverse
        commands << 7
      end
      "\x1b[#{commands.join(";")}m"
    end
  end

  class Tile
    attr_accessor :content
    attr_reader :style

    def initialize
      @content = " "
      @style = TileStyle.new
    end

    CHARS = {
      border_h: "\u2500",
      border_v: "\u2502",
      border_tl: "\u250C",
      border_tr: "\u2510",
      border_bl: "\u2514",
      border_br: "\u2518",
    }

    def empty?
      @content == " " and @style.background.nil?
    end

    def char
      case @content
      when String
        @content
      else
        CHARS.fetch(@content)
      end
    end
  end

  class Canvas
    attr_reader :width, :height, :data

    def initialize(width, height)
      @width = width
      @height = height
      @data = Array.new(@width*@height) { Tile.new }
    end

    def in_bounds?(x, y)
      (x >= 0 && x < @width) and
      (y >= 0 && y < @height)
    end

    def at(x, y)
      if in_bounds?(x, y)
        yield self[x, y]
      end
    end

    def [](x, y)
      @data[y*@width + x]
    end

    def to_lines
      @height.times.map do |y|
        current_code = nil
        line = String.new
        is_empty = true
        @width.times do |x|
          tile = self[x, y]
          style_code = tile.style.to_code
          if style_code != current_code
            line << style_code
            current_code = style_code
          end
          line << tile.char
          is_empty = false if !tile.empty?
        end

        is_empty ? nil : line
      end
    end

    def draw(node)
      node.calculate_layout(@width, @height)
      rect = Rect.new(self, 0, 0, @width, @height, false)
      rect.draw(node)
    end
  end

  class Rect
    attr_reader :width, :height

    def initialize(canvas, x, y, width, height, overflow)
      @canvas = canvas
      @x = x
      @y = y
      @width = width
      @height = height
      @overflow = overflow
    end

    def draw(node)
      node.draw_into(self)

      node.each_child do |child|
        dx, dy, child_width, child_height = *child.layout.map(&:floor)
        new_x = @x + dx - node.offset_x
        new_y = @y + dy - node.offset_y
        rect = Rect.new(@canvas, new_x, new_y, child_width, child_height, @overflow)
        rect.draw(child)
      end
    end

    def at(dx, dy, &blk)
      if !@overflow
        return if dx < 0 || dx >= @width
        return if dy < 0 || dy >= @height
      end

      x = @x + dx
      y = @y + dy

      @canvas.at(x, y, &blk)
    end
  end

  class Terminal
    attr_accessor :input_handler, :focus

    def initialize(console)
      @console = console
      @canvas = nil
      @focus = nil
      @input_handler = InputHandler.new(self)
      @pr, @pw = IO.pipe
      update_size

      trap("WINCH") { update_size }
    end

    def schedule_render
      @pw.write("1")
    end

    def update_size
      @repaint = true
      @height, @width = @console.winsize
    end

    def enter_fullscreen
      @repaint = false
      @console.print("\x1b[?1049h")
    end

    def leave_fullscreen
      @console.print("\x1b[?1049l")
    end

    def hide_cursor
      @console.print("\x1b[?25l")
    end

    def show_cursor
      @console.print("\x1b[?25h")
    end

    def enter_cbreak
      oldt = Termios.tcgetattr(@console)
      newt = oldt.dup
      newt.lflag &= ~Termios::ECHO
      newt.lflag &= ~Termios::ICANON
      Termios.tcsetattr(@console, Termios::TCSANOW, newt)
      oldt
    end

    def leave_cbreak(state)
      Termios.tcsetattr(@console, Termios::TCSANOW, state)
    end

    def new_canvas
      Canvas.new(@width, @height)
    end

    def render(box, prev_lines = [])
      canvas = new_canvas

      box.render
      canvas.draw(box.node)

      # Jump to beginning
      newlines = 0
      lines = canvas.to_lines

      cursor_reset = false

      lines.each_with_index do |line, idx|
        if !@repaint and prev_lines[idx] == line
          # No need to re-render
          newlines += 1
          next
        end

        if !cursor_reset
          @console.print("\x1b[#{newlines+1};1H")
          cursor_reset = true
        elsif newlines == 1
          @console.print("\n")
        elsif newlines > 1
          @console.print("\x1b[#{newlines}E")
        end

        newlines = 0

        if line
          @console.print(line)
        else
          @console.print("\x1b[0m\x1b[2K")
        end

        newlines += 1
      end

      @repaint = false

      lines
    end

    def mount(app, in_fullscreen: true, fps: 3)
      cbreak_state = enter_cbreak
      enter_fullscreen
      hide_cursor

      lines = []
      wait = 1.0/fps
      read_array = [@console, @pr]
      view = app.view
      input_handler = InputHandler.new(app)

      while true
        lines = render(view, lines)
        r, w = IO.select(read_array, nil, nil, wait)
        if r
          r.each do |io|
            next if io == @pr
            data = io.read_nonblock(1024, exception: false)
            next if data == :wait_readable
            return if data.nil?
            input_handler.call(data)
          end
        end
      end
    ensure
      show_cursor
      leave_fullscreen
      leave_cbreak(cbreak_state)
    end
  end

  MainTerminal = Terminal.new(IO.console)
end

