require_relative '../computing/computing'
shape = ->(x){
  func=->(x,y){
    ox,oy=x+0.2,y-0.85
    1.4*x*x+(0.8*y+(y+0.5)/(1.5+32*x*x))**2+(y**4+y**3)/2<1+y/4 || (x.abs<0.05&&y>0) || ox**2+oy**2+1.5*(ox+oy)*oy<0.04
  }
  64.times.map{|y|
    (func[x/32.0,1-y/32.0] ? 1 : 0)<<y
  }.inject(:+)
}
pow=->(i){(128*(i/32.0)**2).round}
sqrt=->(i){(32*Math.sqrt(i/128.0)).round}
puts (-32..32).map{|x|(shape[x]+(1<<65)).to_s(2).gsub(/0/,'00').gsub(/1/,'11')}
puts (-32..32).map{|x|(shape[sqrt[pow[x]]]+(1<<65)).to_s(2).gsub(/0/,'00').gsub(/1/,'11')}

computer = Computer.new do
  array dummy: 128*128
  array data1: 128*128
  array data2: 128*128
  array powmap: 64
  array sqrtmap: 256
  variable :x, :z, :index, :r
  variable :mask0a, :mask0b, :mask1a, :mask1b, :mask2a, :mask2b, :maskshift, :maska, :maskb
  var.maskshift=0
  var.mask0a = 0x00ffffff
  var.mask1a = 0x01ffffff
  var.mask2a = 0x03ffffff
  var.mask0b = 0xfffffffc
  var.mask1b = 0xfffffffe
  var.mask2b = 0xffffffff

  32.times{|i|
    var.powmap[32+i] = (128*(i/32.0)**2).round
    var.powmap[32-i] = (128*(i/32.0)**2).round
  }
  256.times{|i|
    var.sqrtmap[i] = (32*Math.sqrt(i/128.0)).round
  }
  (-32..32).each{|i|
    var.data1[64+i]=shape[i]&0xffffffff
    var.data2[64+i]=shape[i]>>32
  }

  var.index = 128 + 64
  var.x = -28
  exec_while var.x != 29 do
    var.data1[var.index+var.x] = var.data1[var.x+64]
    var.data2[var.index+var.x] = var.data2[var.x+64]
    var.x += 1
  end

  var.z = 2
  var.index += 128
  putc 'P'
  putc 'P'
  putc 'A'
  putc 'P'
  putc "\n"

  exec_while var.z < 29 do
    'line'.each_char{|c| putc c}
    puti var.z
    putc "\n"
    var.x = -28
    exec_if var.z > 8 do
      exec_if var.maskshift == 3 do
        var.maskshift = 0
        var.mask0a += var.mask0a
        var.mask1a += var.mask1a
        var.mask2a += var.mask2a
        var.mask0b += var.mask0b
        var.mask1b += var.mask1b
        var.mask2b += var.mask2b
      end
      var.maskshift += 1
    end
    exec_while var.x != 29 do
      var.r = var.sqrtmap[var.powmap[var.x+32]+var.powmap[var.z+32]]
      var.maska = 0xffffffff
      var.maskb = 0xffffffff
      exec_if var.z > 8  do
        exec_if((var.x==0)|(var.x==-1)|(var.x==1)|(var.x==-2)|(var.x==2)){
          var.maska=var.mask0a;var.maskb=var.mask0b
        }.elsif((var.x==3)|(var.x==-3)){
          var.maska=var.mask1a;var.maskb=var.mask1b
        }.elsif((var.x==4)|(var.x==-4)){
          var.maska=var.mask2a;var.maskb=var.mask2b
        }
      end
      var.data1[var.index+var.x] = var.data1[var.r+64] & var.maska
      var.data2[var.index+var.x] = var.data2[var.r+64] & var.maskb
      var.x += 1
    end
    exec_if var.z == 2 do
      var.data1[var.index+(-1)]=0xffffffff
      var.data1[var.index]=0xffffffff
      var.data1[var.index+1]=0xffffffff
    end
    var.z += 1
    var.index += 128
  end

  var.mask0a = 0
  var.mask0b = 0
  var.mask1a = 0
  var.mask1b = 0
  var.mask2a = 0
  var.mask2b = 0
  var.maskshift = 0
  var.maska = 0
  var.maskb = 0
  var.x = 0
  var.z = 0
  var.index = 0
  var.r = 0
  64.times{|i|var.powmap[i] = 0}
  256.times{|i|var.sqrtmap[i] = 0}
end
File.write 'r.0.0.mca', computer.world_data
