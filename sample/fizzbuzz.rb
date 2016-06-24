require_relative '../computing/computing'
computer = Computer.new do
  variable :mod3, :mod5, :n
  exec_while true do
    var.mod3 += 1
    var.mod5 += 1
    var.n += 1
    exec_if(var.mod3 == 3){
      var.mod3 = 0
      putc 'F';putc 'i';putc 'z';putc 'z'
    }
    exec_if(var.mod5 == 5){
      var.mod5 = 0
      putc 'B';putc 'u';putc 'z';putc 'z'
    }
    exec_if(!!var.mod3 & !!var.mod5){
      puti var.n
    }
    putc ' '
  end
end
File.write 'r.0.0.mca', computer.world_data
