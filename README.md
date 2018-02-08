# Flexmex: Modern terminal applications in Ruby

Flexmex is a library for writing terminal applications using Flexbox and
Ruby. Flexmex is currently a work-in-progress and has limited
documentation and examples. We're still trying to figure out the best
way to write and structure applications.

## Example

The following demonstrates how you write Flexbox in Flexmex. The
complete (runnable) example is available in
[examples/demo.rb](examples/demo.rb).

```ruby
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
```

## Getting started

Build the extension:

```
$ rake
```

Run an example:

```
$ ruby examples/todo.rb
```

