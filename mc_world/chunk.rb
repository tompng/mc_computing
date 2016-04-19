module MCWorld
  class AttributeNode
    def initialize hash, name
      define_singleton_method(:to_h){hash}
      values = hash.map do |key, value|
        [key, AttributeNode.snake_case(key), value]
      end
      cache = {}
      define_singleton_method(:to_s){"#<#{name}:[#{values.map{|a|a[1]}.join(', ')}]>"}
      values.each do |key, method, value|
        define_singleton_method(method){
          cache[method] ||= AttributeNode.construct value.value, "#{name}:#{key}"
        }
      end
    end
    def inspect;to_s;end
    def self.construct value, name
      case value
      when Hash
        new value, name
      when Array
        classname = name.gsub(/ies$/,'y').gsub(/s$/,'')
        value.map{|v|construct v.value, classname}
      else
        value
      end
    end
    def self.snake_case name
      name.gsub(/[A-Z]+/){|c|"_#{[c[0...-1],c[-1]].reject(&:empty?).join('_')}"}.downcase.gsub(/^_/,'')
    end
  end

  class Chunk < AttributeNode
    Attributes = %w(Entities InhabitedTime LastUpdate LightPopulated TerrainPopulated TileEntities TileTicks V xPos zPos)
    attr_accessor *Attributes.map{|key|AttributeNode.snake_case(key)}
    attr_reader :height_map, :biomes, :version
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
          name = "@#{AttributeNode.snake_case(key)}"
          value = AttributeNode.construct level[key], self.class.name
          instance_variable_set name, value
        end
      else
        @version = MCWorld::Tag::Integer.new 176
        @entities = MCWorld::Tag::List.new MCWorld::Tag::Hash, []
        @inhabited_time = MCWorld::Tag::Long.new 0
        @last_update = MCWorld::Tag::Long.new 0
        @light_populated = MCWorld::Tag::Byte.new 1
        @terrain_populated = MCWorld::Tag::Byte.new 1
        @tile_entities = MCWorld::Tag::List.new MCWorld::Tag::Hash, []
        @v = MCWorld::Tag::Byte.new 1
        @x_pos = MCWorld::Tag::Int.new x
        @z_pos = MCWorld::Tag::Int.new z
        @height_map = 16.times.map{16.times.map{0}}
        @biomes = 16.times.map{16.times.map{-1}}
        @sections = MCWorld::Tag::List.new MCWorld::Tag::Hash, []
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
        TileEntities: tile_entities,
        Entities: entities
      }.select{|k,v|v}
      data = {'Level' => MCWorld::Tag::Hash.new(level)}
      data['DataVersion'] = @version if version
      MCWorld::Tag.encode(MCWorld::Tag::Hash.new(data))
    end
    def to_s
      "#<#{self.class.name}:[#{x_pos.value}, #{z_pos.value}]>"
    end
    def [] x, z, y
      section = @sections[y>>4]
      index = ((y&0xf)<<8)|(x<<4)|z
      return nil unless section
      type = (block_halfbyte(section, 'Add', index)<<8)|block_byte(section, 'Blocks', index)
      return nil if type == 0
      Block.new type, *%w(SkyLight BlockLight Data).map{|key|block_halfbyte(section, key, index)}
    end
    def []= x, z, y, block
      si, index = y>>4, ((y&0xf)<<8)|(x<<4)|z
      return if block.nil? && @sections[si].nil?
      section = @sections[si]
      section ||= (0..si).map{|i|
        @sections[i] ||= Tag::Hash.new(
          'Y' => Tag::Byte.new(si),
          'Blocks' => Tag::IntArray.new(4096.times.map{0}),
          'SkyLight' => Tag::IntArray.new(2048.times.map{0}),
          'BlockLight' => Tag::IntArray.new(2048.times.map{0}),
          'Data' => Tag::IntArray.new(2048.times.map{0})
        )
      }.last
      data = {
        'SkyLight' => (block ? block.sky_light : 0),
        'BlockLight' => (block ? block.sky_light : 0),
        'Data' => (block ? block.data : 0)
      }
      type = block ? block.type : 0
      add = type >> 8
      block = type & 0xff
      data.each do |key, value|
        block_halfbyte_set section, key, index, value
      end
      section.value['Add'] ||= Tag::IntArray.new(2048.times.map{0}) if add>0
      block_halfbyte_set section, 'Add', index, add if section['Add']
      section['Blocks'][index] = block
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
      arr[index/2]&=0xf<<4*(index&1)
      arr[index/2]|=value<<4*(1-index&1)
    end
    def block_halfbyte section, key, index
      arr = section[key]
      arr ? ((arr[index/2]&0xff)>>4*(1-index&1))&0xf : 0
    end
  end
end
