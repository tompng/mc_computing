require './mc_world/world'
require 'pry'
mc=MCWorld::World.new file: "r.-1.-1.mca"
chunk = mc[0,8]
p chunk #=> #<MCWorld::Chunk:[-32, -24]>
p chunk.height_map[0][2] #=> 64
p chunk[0,2,63] #<MCWorld::Chunk::Block:0x007fd1718ea8d8 @type=12, @sky_light=0, @block_light=0, @data=0>

sec=Zlib.inflate mc.sectors[256];
p chunk.encode == sec

infile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca.backup'
outfile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca'
world = MCWorld::World.new file: infile

world = MCWorld::World.new file: outfile
chunk = world[16,14]

chunk[1,15,72]=MCWorld::Block::Chest[5]
chunk[1,15,71]=MCWorld::Block::DiamondBlock
chunk[1,15,70]=MCWorld::Block::Chest[5]
chunk.tile_entities[1,15,70]=MCWorld::TileEntity::Chest.end_city_treasure_chest

(1..5).each{|i|(1..5).each{|j|
  chunk[3*i,3*j,65+10]=MCWorld::Block::Chest
  chunk[3*i-1,3*j,66+10]=MCWorld::Block::Chest
  chunk[3*i,3*j-1,67+10]=MCWorld::Block::Chest
  chunk[3*i-1,3*j-1,64+10]=MCWorld::Block::Chest
}}
16.times{|i|16.times{|j|chunk.height_map[i][j]=80}}
chunk[1,15,66]=MCWorld::Block::Stone
chunk[1,14,66]=MCWorld::Block::Chest
chunk[1,16,66]=MCWorld::Block::Chest
chunk.light_populated.value = 0
File.write outfile, world.encode
exit
binding.pry

32.times{|i|32.times{|j|
  chunk = world[i,j]
  next unless chunk
  16.times{|x|16.times{|z|
    y=chunk.height_map[x][z]
    (1..y).each do |y|
      block = chunk[x,z,y]
      next unless block
      chunk[x,z,y]=MCWorld::Block::DiamondOre if block.type==MCWorld::Block::Stone
    end
  }}
  chunk.light_populated.value = 0
}}

File.write outfile, world.encode