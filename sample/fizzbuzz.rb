require_relative '../computing/computing'
save_dir = '~/Library/Application Support/minecraft/saves/' #if Mac
world_name = 'computer'
outfile = File.expand_path "#{save_dir}#{world_name}/region/r.0.0.mca"
computer = Computer.new
computer.code do
  variable :mod3, :mod5, :n
  var.mod3 = 0
  var.mod5 = 0
  exec_while(1) do
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
File.write outfile, computer.encode