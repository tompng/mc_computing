require_relative '../mc_world/world'
require 'pry'
outfile='r.0.0.mca'
outfile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca'
world = MCWorld::World.new x: 0, z: 0

def waterlevel hmap
  wmap = hmap.map(&:dup)
  w, h = wmap.size, wmap.first.size
  xys = w.times.to_a.product h.times.to_a
  around=->x,y{
    [
      ([x+1,y] if x<w-1),
      ([x-1,y] if x>0),
      ([x,y+1] if y<h-1),
      ([x,y-1] if y>0)
   ].compact
  }
  lowests = xys.select{|x,y|
    around[x,y].size==4&&around[x,y].all?{|ax,ay|
      wmap[x][y]<wmap[ax][ay]
    }
  }
  lowests.each do |x,y|
    next if wmap[x][y]!=hmap[x][y]
    p [x,y]
    heap=MCWorld::Heap.new &:first
    waters = Set.new
    zlevel = wmap[x][y]
    heap << [zlevel,x,y]
    added = Set.new
    added << [x,y]
    until heap.empty?
      z,x,y = heap.pop
      waters << [x,y] if z <= zlevel
      z2,_,_ = heap.first
      min = around[x,y].map{|x,y|
        next nil if waters.include? [x,y]
        unless added.include? [x,y]
          heap << [wmap[x][y],x,y]
          added << [x,y]
        end
        wmap[x][y]
      }.compact.min
      min=0 if around[x,y].size!=4
      break if min && min < zlevel
      zlevel = [min, z2].compact.min || zlevel
    end
    waters.each do |x,y|
      wmap[x][y]=zlevel
    end
  end
  wmap
end


# hmap = [
# [99,98,97,96,95],
# [89,00,78,79,94],
# [88,76,77,84,93],
# [87,80,85,02,92],
# [86,82,83,80,91]]
# wmap = waterlevel hmap
# binding.pry

def randmap3d x,y,z,scale:1,scalex:scale,scaley:scale,scalez:scale
  s1.times.map{
    s2.times.map{
      s3.times.map{2*rand-1}
    }
  }
  av=->(arr,scale){
  }
end

def posrand
  xx,xy,xz,zx,zy,zz,yx,yy,yz=9.times.map{rand}
  x, z, y = [x+Math.sin(xx*x+xy*y+xz*z),z+Math.sin(zx*x+zy*y+zz*z),y+Math.sin(yx*x+yy*y+yz*z)]
end

xsmooth=->arr{
  512.times.map{|i|
    range = 48
    sum = (-range..range).map{|k|arr[i][k]}.inject(:+)
    512.times.map{|j|
      s = sum
      sum += arr[i][(j+range+1)%512]
      sum -= arr[i][(j-range)%512]
      s
    }
  }
}
hmap=512.times.map{512.times.map{rand}}
hmap=xsmooth[xsmooth[hmap].transpose]
hmap=xsmooth[xsmooth[hmap].transpose]
min,max=hmap.flatten.min,hmap.flatten.max
512.times{|i|512.times{|j|
  hmap[i][j]=50+64*(hmap[i][j]-min)/(max-min)
}}
binding.pry
wmap = waterlevel hmap
binding.pry


(0...32*16).each do |x|
  (0...32*16).each do |z|
    world[x,z,0]=MCWorld::Block::Bedrock
    world[x,z,1]=MCWorld::Block::StillLava
    h=hmap[x][z].to_i
    w=wmap[x][z].to_i
    h=10 if h<10
    h=255-10 if h>255-10
    w=10 if w<10
    w=255-10 if w>255-10
    (1..h).each do |y|
      world[x,z,y]=y==h ? MCWorld::Block::Grass : MCWorld::Block::Dirt if Math.sin(0.1*x+0.15*y)+Math.sin(0.1*z+0.15*y)>-1.5
    end
    (h+1..w).each{|y|world[x,z,y]=MCWorld::Block::StillWater}
  end
  p x
end
File.write outfile, world.encode
