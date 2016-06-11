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
        parse_sections level['Sections']
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
        @blocks = []
        @tile_entities = MCWorld::TileEntity::Entities.new x_pos.value*16, z_pos.value*16, []
      end
    end

    def to_h
      @hash
    end
    def recalc_height_map
      ymax = @blocks.size
      16.times{|x|16.times{|z|
        height = (0..ymax).reverse_each.find{|y|
          (level = @blocks[y]) && (block = level[x][z]) && !block.sky_light_transparent?
        }
        height_map[x][z] = height ? height+1 : 0
      }}
    end
    def encode
      recalc_height_map
      level = {
        LightPopulated: light_populated,
        zPos: z_pos,
        HeightMap: MCWorld::Tag::IntArray.new(height_map.flatten),
        TileTicks: tile_ticks,
        Sections: sections,
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
      xzmap = @blocks[y]
      xzmap && xzmap[x][z]
    end
    def []= x, z, y, block
      (@blocks[y] ||= 16.times.map{[]})[x][z]=block
      tile_entities[x, z, y] = nil
    end
    private
    def parse_sections sections
      @blocks = []
      sections.value.each_with_index do |section, yindex|
        id_array = section['Blocks']
        add_array = section['Add']
        data_array = section['Data']
        16.times.each do |y|
          xzmap = @blocks[16*yindex+y] ||= []
          16.times.each do |x|
            xzmap[x] ||= []
            16.times.each do |z|
              index = (y<<8)|(z<<4)|x
              shift = 4*(index&1)
              id = id_array[index]&0xff
              add = add_array ? (add_array[index/2]>>shift)&0xf : 0
              data = (data_array[index/2]>>shift)&0xf
              xzmap[x][z] = MCWorld::Block[(add<<8)|id, data]
            end
          end
        end
      end
    end
    def sections
      MCWorld::Tag::List.new MCWorld::Tag::Hash, (0..@blocks.size>>4).map{|yi|
        id_array = 4096.times.map{0}
        add_array = nil
        data_array = 2048.times.map{0}
        16.times.map{|y|
          16.times.map{|x|
            16.times.map{|z|
              xzmap = @blocks[16*yi+y]
              block = xzmap && xzmap[x][z]
              next unless block
              index = (y<<8)|(z<<4)|x
              shift = 4*(index&1)
              id = block.id&0xff
              add = block.id>>8
              id_array[index] = id
              data_array[index/2]&=0xf<<4*(1-index&1)
              data_array[index/2]|=block.data<<4*(index&1)
              if add > 0
                add_array ||= 2048.times.map{0}
                add_array[index/2]&=0xf<<4*(1-index&1)
                add_array[index/2]|=add<<4*(index&1)
              end
            }
          }
        }
        section_hash = {
          'Y' => Tag::Byte.new(yi),
          'Blocks' => Tag::ByteArray.new(id_array),
          'SkyLight' => Tag::ByteArray.new(2048.times.map{0}),
          'BlockLight' => Tag::ByteArray.new(2048.times.map{0}),
          'Data' => Tag::ByteArray.new(data_array),
        }
        section_hash['Add'] = Tag::ByteArray.new add_array if add_array
        Tag::Hash.new section_hash
      }
    end
  end
end
