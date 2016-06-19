require_relative '../computing/computing'
computer = Computer.new do
  array data: 127*128
  variable :x, :y, :index, :shape
  var.shape = 1
  var.data[0] = var.shape
  var.y = 0
  exec_while var.y < 127 do
    var.x = 0
    var.shape += var.shape + 1
    var.data[var.index+128] = var.shape
    exec_while var.x <= var.y do
      exec_if !!var.data[var.index+var.x] + !!var.data[var.index+var.x+1] == 1 do
        var.data[var.index+var.x+129] = var.shape
      end
      var.x += 1
    end
    var.y += 1
    var.index += 128
  end
end
File.write 'r.0.0.mca', computer.world_data
#replace "<minecraft_save_dir>/<world_name>/region/r.0.0.mca" with "./r.0.0.mca"
#for mac, it's "~/Library/Application Support/minecraft/saves/<world_name>/region/r.0.0.mca"
