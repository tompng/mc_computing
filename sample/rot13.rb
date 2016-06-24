require_relative '../computing/computing'
computer = Computer.new do
  array input: 256
  variable :i, :j, :c
  "rot13\n".each_char{|c|putc c}
  exec_while true do
    var.i = 0
    var.c = 0
    putc '>'
    exec_while var.c != "\n" do
      var.c = getc
      var.input[var.i] = var.c
      putc var.c
      var.i += 1
    end
    var.j = 0
    exec_while var.j < var.i do
      var.c = var.input[var.j]
      exec_if((var.c >= 'a') & (var.c <= 'z')){
        var.c += 13
        exec_if(var.c > 'z'){var.c += 'a'.ord-'z'.ord-1}
      }.elsif((var.c >= 'A') & (var.c <= 'Z')){
        var.c += 13
        exec_if(var.c > 'Z'){var.c += 'A'.ord-'Z'.ord-1}
      }
      putc var.c
      var.j += 1
    end
  end
end
File.write 'r.0.0.mca', computer.world_data
