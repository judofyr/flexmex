$LOAD_PATH << __dir__ + '/../lib'

require 'flexmex'

include Flexmex
include Flexmex::Constants

class NewTodo
  def initialize
    @current_text = ""
  end

  def view
    Flexmex::Box.new(flex: 1) do |b|
      b.text "Create new todo:", bold: true
      b.text -> { @current_text }, border: 1
    end
  end

  def handle_key(key)
    case key
    when String
      @current_text += key
    when :backspace
      @current_text.chop!
    end
  end

  def take
    @current_text
  ensure
    @current_text = ""
  end
end

class TodoItem
  attr_accessor :text

  def initialize(text)
    @text = text
    @is_completed = false
  end

  def toggle
    @is_completed = !@is_completed
  end

  def title
    if @is_completed
      "[X] #{@text}"
    else
      "[ ] #{@text}"
    end
  end
end

class TodoList
  attr_accessor :items

  def initialize
    @items = []
    @current = nil
  end

  def <<(item)
    @items << item
  end

  def active?
    !!@current
  end

  def current?(item)
    @current == item
  end

  def activate
    @current ||= @items.first
  end

  def deactivate
    @current = nil
  end

  def current_index(extra = 0)
    if pos = @items.index(@current)
      [pos + extra, 0].max
    end
  end

  def title
    "#{@items.size} items"
  end

  def view
    Flexmex::Box.new(flex: 1) do |b|
      b.text -> { title }, align_self: Center
      b.list -> { @items } do |item|
        Flexmex::Box.new do |b|
          b.text -> { item.title },
            inverse: -> { current?(item) }
        end
      end
    end
  end

  def handle_key(key)
    case key
    when :up
      if @current
        idx = current_index(-1)
        @current = idx && @items[idx]
      else
        @current = @items[-1]
      end
    when :down
      if @current
        idx = current_index(+1)
        @current = idx && @items[idx]
      else
        @current = @items[0]
      end
    when " "
      if @current
        @current.toggle
      end
    end
  end
end

class TodoApp
  def initialize
    @list = TodoList.new
    @creator = NewTodo.new
  end

  def view
    Flexmex::Box.new do |b|
      b.flex_direction = Row
      b.add @creator
      b.add @list
    end
  end

  def handle_key(key)
    case key
    when :enter
      create_item
    when :up, :down
      @list.handle_key(key)
    when :right
      @list.activate
    when :left, :escape
      @list.deactivate
    else
      if @list.active?
        @list.handle_key(key)
      else
        @creator.handle_key(key)
      end
    end
  end

  def create_item
    text = @creator.take.strip
    if !text.empty?
      item = TodoItem.new(text)
      @list << item
    end
  end
end

app = TodoApp.new
Flexmex.mount(app)

