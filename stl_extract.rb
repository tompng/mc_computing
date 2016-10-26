require_relative 'mc_world/world'

file = ARGV[0]
unless file =~ /.*\.mca/
  puts "file not found: #{file.inspect}"
  exit
end

world = MCWorld::World.new file: file

table = {}
set = ->(x,y,z){table[((x&0xff)<<16)|((y&0xff)<<8)|(z&0xff)]=true}
get = ->(x,y,z){table[((x&0xff)<<16)|((y&0xff)<<8)|(z&0xff)]}
x0, y0 = 128, 256
128.times{|x|128.times{|y|128.times{|z|set[x,z,y] if world[x0+x,y0+y,z]}}}

def stl name='shape'
  puts "solid #{name}"
  yield
  puts "endsolid #{name}"
end
def face pos, dir
  val, axis = dir.each.with_index.find{ |val, axis| val.nonzero? }
  p00, p01, p10, p11 = 4.times.map { dir.dup }
  p00[ (axis+1) % 3] = -1
  p00[ (axis+2) % 3] = -1
  p01[ (axis+1) % 3] = -1
  p01[ (axis+2) % 3] = +1
  p10[ (axis+1) % 3] = +1
  p10[ (axis+2) % 3] = -1
  p11[ (axis+1) % 3] = +1
  p11[ (axis+2) % 3] = +1
  p10, p01 = p01, p10 if val < 0
  vertex = ->(p){pos.zip(p).map{|ps,p|ps+(1+p)/2}.join ' '}
  puts %(
    facet normal #{dir.join ' '}
      outer loop
        vertex #{vertex[p00]}
        vertex #{vertex[p10]}
        vertex #{vertex[p11]}
      endloop
    endfacet
    facet normal #{dir.join ' '}
      outer loop
        vertex #{vertex[p00]}
        vertex #{vertex[p11]}
        vertex #{vertex[p01]}
      endloop
    endfacet
  )
end

stl 'applepen' do
  128.times{|x|128.times{|y|128.times{|z|
    next unless get[x,y,z]
    [[-1,0,0],[1,0,0],[0,-1,0],[0,1,0],[0,0,-1],[0,0,1]].each{|dx,dy,dz|
      face [x,y,z], [dx,dy,dz] unless get[x+dx,y+dy,z+dz]
    }
  }}}
end
