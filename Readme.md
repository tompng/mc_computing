## Minecraft Computer World Data

https://www.youtube.com/watch?v=UmBkiT6eYYA

```ruby
computer = Computer.new do
  variable :i
  exec_while(var.i < 10) do
    "Hello World ".chars.each{|c|putc c}
    puti var.i
    putc "\n"
    var.i += 1
  end
end
File.write 'r.0.0.mca', computer.world_data
#replace "<minecraft_save_dir>/<world_name>/region/r.0.0.mca" with "./r.0.0.mca"
#for mac, it's "~/Library/Application Support/minecraft/saves/<world_name>/region/r.0.0.mca"
```
![sample](https://dl.dropboxusercontent.com/u/102060740/mc_helloworld.png)
