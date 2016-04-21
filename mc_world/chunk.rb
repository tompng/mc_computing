module MCWorld
  class Chunk
    Attributes = %w(Entities InhabitedTime LastUpdate LightPopulated TerrainPopulated TileTicks V xPos zPos)
    attr_accessor *Attributes.map{|key|Util.snake_case(key)}
    attr_reader :height_map, :biomes, :version, :tile_entities
    def initialize data: nil, x: nil, z: nil
      if data
        hash = MCWorld::Tag.decode(data)
        @version = hash['DataVersion']
        level = hash['Level']
        @hash = hash
        @height_map = level['HeightMap'].value.each_slice(16).to_a
        @biomes = level['Biomes'].value.each_slice(16).to_a
        @sections = level['Sections']
        Attributes.each do |key|
          instance_variable_set "@#{Util.snake_case(key)}", level[key]
        end
        @tile_entities = MCWorld::TileEntity::Entities.new x_pos.value*16, z_pos.value*16, level['TileEntities'].value
      else
        @version = MCWorld::Tag::Int.new 176
        @entities = MCWorld::Tag::List.new MCWorld::Tag::Hash, []
        @inhabited_time = MCWorld::Tag::Long.new 0
        @last_update = MCWorld::Tag::Long.new 0
        @light_populated = MCWorld::Tag::Byte.new 0
        @terrain_populated = MCWorld::Tag::Byte.new 1
        @v = MCWorld::Tag::Byte.new 1
        @x_pos = MCWorld::Tag::Int.new x
        @z_pos = MCWorld::Tag::Int.new z
        @height_map = 16.times.map{16.times.map{0}}
        @biomes = 16.times.map{16.times.map{-1}}
        @sections = MCWorld::Tag::List.new MCWorld::Tag::Hash, []
        @tile_entities = MCWorld::TileEntity::Entities.new x_pos.value*16, z_pos.value*16, []
      end
    end
    def to_h
      @hash
    end
    def encode
      level = {
        LightPopulated: light_populated,
        zPos: z_pos,
        HeightMap: MCWorld::Tag::IntArray.new(height_map.flatten),
        TileTicks: tile_ticks,
        Sections: @sections,
        LastUpdate: last_update,
        V: v,
        Biomes: MCWorld::Tag::ByteArray.new(biomes.flatten),
        InhabitedTime: inhabited_time,
        xPos: x_pos,
        TerrainPopulated: terrain_populated,
        TileEntities: tile_entities.encode_data,
        Entities: entities
      }.select{|k,v|v}
      data = {'Level' => MCWorld::Tag::Hash.new(level)}
      data['DataVersion'] = @version if version
      MCWorld::Tag.encode(MCWorld::Tag::Hash.new(data))
    end
    def to_s
      "#<#{self.class.name}:[#{x_pos.value}, #{z_pos.value}]>"
    end
    def inspect
      to_s
    end
    def [] x, z, y
      section = @sections[y>>4]
      index = ((y&0xf)<<8)|(z<<4)|x
      return nil unless section
      type = (block_halfbyte(section, 'Add', index)<<8)|block_byte(section, 'Blocks', index)
      return nil if type == 0
      data = block_halfbyte section, 'Data', index
      Block[type, data]
    end
    def []= x, z, y, block
      si, index = y>>4, ((y&0xf)<<8)|(z<<4)|x
      return if block.nil? && @sections[si].nil?
      section = @sections[si]
      section ||= (0..si).map{|i|
        @sections[i] ||= Tag::Hash.new(
          'Y' => Tag::Byte.new(i),
          'Blocks' => Tag::ByteArray.new(4096.times.map{0}),
          'SkyLight' => Tag::ByteArray.new(2048.times.map{0}),
          'BlockLight' => Tag::ByteArray.new(2048.times.map{0}),
          'Data' => Tag::ByteArray.new(2048.times.map{0})
        )
      }.last
      id = block ? block.id : 0
      block_add = id >> 8
      block_id = id & 0xff
      section.value['Add'] ||= Tag::ByteArray.new(2048.times.map{0}) if block_add>0
      section['Blocks'][index] = block_id
      block_halfbyte_set section, 'Add', index, block_add if section['Add']
      block_halfbyte_set section, 'Data', index, block ? block.data : 0
      tile_entities[x, z, y] = nil
    end
    def compact
      @sections.each do |section|
        section.value.delete 'Add' if section['Add'].all? &:zero?
      end
      @sections.pop while @sections.last['Add'].nil? && sections.last['Blocks'].all?(&:zero?)
    end
    private
    def block_byte section, key, index
      arr = section[key]
      arr ? arr[index]&0xff : 0
    end
    def block_halfbyte_set section, key, index, value
      arr = section[key]
      val = arr[index/2]
      arr[index/2]&=0xf<<4*(1-index&1)
      arr[index/2]|=value<<4*(index&1)
    end
    def block_halfbyte section, key, index
      arr = section[key]
      arr ? ((arr[index/2]&0xff)>>4*(index&1))&0xf : 0
    end
  end
end
