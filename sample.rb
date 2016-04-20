require './mc_world/world'
require 'pry'
infile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca.backup'
outfile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca'
world = MCWorld::World.new file: infile
chunk = world[16,14]

p chunk #=> #<MCWorld::Chunk:[16, 14]>
p chunk.height_map[0][2] #=> 67
p chunk[0,2,66] #=> MCWorld::Block::Grass

16.times{|i|16.times{|j|chunk.height_map[i][j]=80}}
(0..14).each{|i|(0..14).each{|j|
  (64..80).each{|k|
    if i.odd?&&j.odd?
      chunk[i,j,k]=MCWorld::Block::Chest[rand(2..5)]
      chunk.tile_entities[i,j,k]=MCWorld::TileEntity::Chest.end_city_treasure_chest
    else
      chunk[i,j,k]=MCWorld::Block::Glowstone
    end
  }
}}
chunk.light_populated.value = 0
File.write outfile, world.encode

world = MCWorld::World.new x: 0, z: 0
(14..18).each{|cx|(14..18).each{|cz|
  chunk = world[cx,cz]
  16.times{|x|16.times{|z|
    chunk.height_map[x][z]=64
    64.times{|y|chunk[x,z,y]=rand<0.9 ? MCWorld::Block::Stone : MCWorld::Block[rand(1..30)]}
  }}
}}
File.write outfile, world.encode
binding.pry
