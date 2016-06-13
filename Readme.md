## Minecraft Computer World Data
```ruby
Computer.new do
  add_compiled_code DSL::Runtime.new{
    variable :a, :b, :c
    var.a = '0'
    exec_while(var.a) do
      "Hello World".chars.each do |c|
        putc c
      end
      var.a += 1
      putc var.a
      putc "\n"
    end
  }.compile
  File.write 'r.0.0.mca', @world.encode
end
```
[sample](https://cloud.githubusercontent.com/assets/1780201/16016086/f4e07cca-31d3-11e6-9996-9dd8a70df6c2.png])
