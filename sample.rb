require './mc_world/world'
require 'pry'
mc=MCWorld::World.new file: "r.-1.-1.mca"
chunk = mc[0,8]
p chunk #=> #<MCWorld::Chunk:[-32, -24]>
p chunk.height_map[0][2] #=> 64
p chunk[0,2,63] #<MCWorld::Chunk::Block:0x007fd1718ea8d8 @type=12, @sky_light=0, @block_light=0, @data=0>

sec=Zlib.inflate mc.sectors[256];
p chunk.encode == sec

infile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca.original'
outfile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca'
world = MCWorld::World.new file: infile

32.times{|i|32.times{|j|
  chunk = world[i,j]
  next unless chunk
  16.times{|x|16.times{|z|
    y=chunk.height_map[x][z]
    chunk[x,z,y-1]=MCWorld::Block.new(19,0,0,0)
  }}
  chunk.light_populated.value = 0
}}

File.write outfile, world.encode