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
![sample](https://dl.dropboxusercontent.com/u/102060740/mc_helloworld.png)
