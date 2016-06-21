require_relative '../computing/computing'
computer = Computer.new do
  array data: 128*128
  variable :x, :y, :index, :shape
  "Memory 3D Plot\n".each_char{|c|putc c}
  var.shape = 1
  var.data[0] = var.shape
  putc '#'
  exec_while var.y < 127 do
    putc "\n"
    var.x = 0
    var.shape = var.shape ^ (var.shape + var.shape)
    var.data[var.index+128] = var.shape
    putc '#'
    exec_while var.x <= var.y do
      exec_if(!!var.data[var.index+var.x] + !!var.data[var.index+var.x+1] == 1){
        var.data[var.index+var.x+129] = var.shape
        putc '#'
      }.else{
        putc ' '
      }
      var.x += 1
    end
    var.y += 1
    var.index += 128
  end
end
File.write 'r.0.0.mca', computer.world_data
