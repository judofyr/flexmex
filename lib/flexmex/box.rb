module Flexmex
  class StaticChild
    def initialize(boxes)
      @boxes = []
      @next_boxes = boxes
    end

    def update
      old_boxes = @boxes
      new_boxes = @next_boxes
      new_boxes.each(&:render)

      @boxes = new_boxes
      return old_boxes, new_boxes
    end
  end

  class SingleChild
    def initialize(box_builder)
      @box_builder = box_builder
      @boxes = []
    end

    def update
      new_box = @box_builder.call
      old_boxes = @boxes
      new_boxes = [new_box]
      new_box.render

      @boxes = new_boxes
      return old_boxes, new_boxes
    end
  end

  class ListChild
    def initialize(items_builder, renderer)
      @items_builder = items_builder
      @renderer = renderer
      @boxes = []
      @positions = {}
    end

    def update
      old_boxes = @boxes
      old_positions = @positions

      new_boxes = []
      new_positions = {}

      items = @items_builder.call

      items.each_with_index do |item, idx|
        prev_idx = old_positions[item]
        box = prev_idx ? old_boxes[prev_idx] : @renderer.call(item)
        box.render
        new_positions[item] = idx
        new_boxes << box
      end

      @boxes = new_boxes
      @positions = new_positions
      return old_boxes, new_boxes
    end
  end

  class Box
    include Flexmex::Constants

    def initialize(props = {})
      @_children = []
      @_on_render = []

      set(props)
      yield self if block_given?
      setup
      @_children.freeze
    end

    def setup
      # do nothing
    end

    def node
      @node ||= BoxNode.new
    end

    def self.define_node_helper(node_name, name)
      class_eval <<-EOF, __FILE__, __LINE__ + 1
        def #{name}(value)
          auto_call(value) do |val|
            #{node_name}.#{name} val
          end
        end
      EOF
    end

    def self.define_node_helpers(node_name, klass)
      klass.instance_methods(false).grep(/=$/).each do |name|
        define_node_helper(node_name, name)
      end
    end

    define_node_helpers :node, BoxNode

    def auto_call(value)
      if value.respond_to?(:call)
        on_render { yield value.call }
      else
        yield value
      end
    end

    def set(props = {})
      props.each do |key, value|
        setter_name = :"#{key}="
        send(setter_name, value)
      end
    end

    def add(box)
      if box.respond_to?(:view)
        box = box.view
      end

      if box.respond_to?(:call)
        child = SingleChild.new(box)
      else
        child = StaticChild.new([box])
      end
      @_children << child
      self
    end

    ID = proc { |i| i }

    def list(items, &blk)
      blk ||= ID

      if items.respond_to?(:call)
        child = ListChild.new(items, blk)
      else
        child = StaticChild.new(items.map(&blk))
      end
      @_children << child
      self
    end

    def text(text, opts = {})
      add(Text.new(opts.merge(content: text)))
    end

    def box(opts = {}, &blk)
      add(Box.new(opts, &blk))
    end

    def on_render(blk = Proc.new)
      @_on_render << blk
      blk.call
      self
    end

    def render
      @_on_render.each(&:call)

      idx = 0
      @_children.each do |child|
        prev_boxes, new_boxes = child.update

        if prev_boxes != new_boxes
          prev_boxes.each do |box|
            node.remove_child(box.node)
          end

          new_boxes.each do |box|
            node.insert_child(box.node, idx)
            idx += 1
          end
        else
          idx += new_boxes.size
        end
      end
    end
  end

  class Text < Box
    def text_node
      @text_node ||= TextNode.new
    end

    def setup
      node.insert_child(text_node, 0)
    end

    define_node_helpers :text_node, TextNode
  end
end

