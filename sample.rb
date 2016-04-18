require './mc_world/world'
require 'pry'
mc=MCWorld::World.new file: "r.-1.-1.mca"
chunk = mc[0,8]
p chunk #=> #<MCWorld::Chunk:[-32, -24]>
p chunk.height_map[0][2] #=> 64
p chunk[0,2,63] #<MCWorld::Chunk::Block:0x007fd1718ea8d8 @type=12, @sky_light=0, @block_light=0, @data=0>

sec=Zlib.inflate mc.sectors[256];
p chunk.encode == sec
binding.pry