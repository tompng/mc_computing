require_relative '../computing/computing'
computer = Computer.new do
  array input: 256
  variable :i, :c
  "flip word".each_char{|c|putc c}
  exec_while true do
    var.c = 0
    putc "\n";putc '>'
    exec_while var.c != "\n" do
      var.c = getc
      var.input[var.i] = var.c
      putc var.c
      var.i += 1
    end
    var.i += -1
    exec_while var.i do
      var.i += -1
      putc var.input[var.i]
    end
  end
end
File.write 'r.0.0.mca', computer.world_data
