## Minecraft world file(.mca) reader/writer
%|
```ruby
#|
require './mc_world/world'
require 'pry'
infile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca.backup'
outfile='/Users/tomoya/Library/Application Support/minecraft/saves/rubytest/region/r.0.0.mca'
world = MCWorld::World.new file: infile

chunk = world.chunk 16, 14
p chunk #=> #<MCWorld::Chunk:[16, 14]>
p chunk.height_map[0][2] #=> 67
p chunk[0,2,66] #=> MCWorld::Block::Grass
p chunk[0,2,66] = MCWorld::Block::DiamondBlock #=> MCWorld::Block::DiamondBlock
File.write outfile, world.encode

world = MCWorld::World.new x: 0, z: 0
range = 14*16...18*16
range.each{|x|range.each{|z|
  64.times{|y|world[x,z,y]=rand<0.9 ? MCWorld::Block::Stone : MCWorld::Block[rand(1..30)]}
  world[x,z,64] = MCWorld::Block::Glowstone if rand < 0.01
  world[x,z,64] = MCWorld::Block::EnderChest if rand < 0.01
  if rand < 0.01
    world[x,z,64] = MCWorld::Block::Chest[rand(2..5)]
    world.tile_entities[x,z,64]=MCWorld::TileEntity::Chest.end_city_treasure_chest
  end
  if rand < 0.01
    world[x,z,64] = MCWorld::Block::TrappedChest[rand(2..5)]
    world.tile_entities[x,z,64]=MCWorld::TileEntity::Chest.chest items: [
      'minecraft:elytra',
      {id: 'minecraft:diamond_block', count: 64},
      {id: 'minecraft:iron_block', count: 64}
    ]*9
  end
}}

range2 = (12*16...20*16)
range2.each{|x|range2.each{|z|
  32.times{|y|world[x,z,y] = nil}
  world[x,z,0] = MCWorld::Block::Bedrock
}}
File.write outfile, world.encode
binding.pry
__END__
```
