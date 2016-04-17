require 'pry'
require 'zlib'

class MinecraftRegion
  def to_s
    "#<#{self.class.name}:#{@file}>"
  end
  def inspect
    to_s
  end

  def initialize file
    @file = file
    @mcadata = File.binread file
    @chunks = {}
  end

  def chunk x,z
    @chunks[[x,z]] ||= Chunk.new(parse_chunk(x,z))
  end

  def parse_chunk x,z
    sector = decode_sector 32*z+x
    TagParser.parse(sector)['Level']
  end

  private
  def decode_sector i
    location = @mcadata[4*i,4].unpack('N')[0]
    sector = location>>8
    sector_size = location&0xff
    size, compress = @mcadata[sector*4096,5].unpack('Nc')
    Zlib.inflate @mcadata[sector*4096+5,size-1]
  end

  class MCNode
    def initialize hash, name
      define_singleton_method(:to_h){hash}
      values = hash.map do |key, value|
        [key, MCNode.snake_case(key), value]
      end
      cache = {}
      define_singleton_method(:to_s){"#<#{name}:[#{values.map{|a|a[1]}.join(', ')}]>"}
      values.each do |key, method, value|
        define_singleton_method(method){
          cache[method] ||= MCNode.construct value, "#{name}:#{key}"
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
        value.map{|v|construct v, classname}
      else
        value
      end
    end
    def self.snake_case name
      name.gsub(/[A-Z]+/){|c|"_#{[c[0...-1],c[-1]].reject(&:empty?).join('_')}"}.downcase.gsub(/^_/,'')
    end
  end

  class Chunk < MCNode
    attr_reader :height_map, :biomes
    def initialize hash
      hash = hash.dup
      @height_map = hash.delete('HeightMap').each_slice(16).to_a
      @biomes = hash.delete('Biomes').each_slice(16).to_a
      sections = hash.delete 'Sections'
      define_singleton_method :block do |x, z, y|
        Block.new sections, x, z, y
      end
      super hash, self.class.name
      define_singleton_method(:to_s){
        "#<#{self.class.name}:[#{x_pos}, #{z_pos}]>"
      }
    end
    class Block
      Axis = %i(x z y)
      Attributes = %w(SkyLight BlockLight Data).map{|attr|
        [MCNode.snake_case(attr), attr]
      }.to_h
      attr_reader *Axis
      def initialize sections, x, z, y
        @x, @z, @y = x, z, y
        @section = sections[y>>4] || {}
        @index = ((y&0xf)<<8)|(x<<4)|z
      end
      def to_s
        keys = [*Axis, :id, *Attributes.keys]
        "#<#{self.class.name}:{#{keys.map{|a|"#{a}: #{send a}"}.join(', ')}>"
      end
      def id
        (halfbyte('Add')<<8)|byte('Blocks')
      end
      Attributes.each do |name, attr|
        define_method name do
          halfbyte attr
        end
      end
      def inspect;to_s;end
      private
      def byte key
        arr = @section[key]
        arr ? arr[@index]&0xff : 0
      end
      def halfbyte key
        arr = @section[key]
        arr ? (arr[@index/2]&0xff)>>((@index&1)*4) : 0
      end
    end
  end

  module TagParser
    type_unpack = ->size,type{
      ->(s,i){[i+size, s[i,size].unpack(type)[0]]}
    }
    TagByte = type_unpack[1,'c']
    TagShort = type_unpack[2,'s>']
    TagInt = type_unpack[4,'l>']
    TagLong = ->(s,i){
      a,b=s[i,8].unpack('NN')
      n=(a<<32)|b
      n-=1<<64 if n>=1<<63
      [i+8,n]
    }
    TagFloat = type_unpack[4,'g']
    TagDouble = type_unpack[8,'G']
    TagByteArray = ->(s,i){
      i,size=TagInt[s,i]
      [i+size, s[i,size].unpack('c*')]
    }
    TagIntArray = ->(s,i){
      i,size=TagInt[s,i]
      [i+size*4, s[i,size*4].unpack('l>*')]
    }
    TagString = ->(s,i){
      i,size=TagShort[s,i]
      [i+size, s[i,size]]
    }
    TagList = ->(s,idx){
      idx,type=TagByte[s,idx]
      idx,size=TagInt[s,idx]
      list = size.times.map{|i|
        idx,data=TagTypes[type][s,idx]
        data
      }
      [idx, list]
    }
    TagHash = ->(s,idx){
      hash = {}
      loop do
        idx, type = TagByte[s,idx]
        break if type.nil? || type.zero?
        name_size = s[idx,2].unpack('n')[0]
        name = s[idx+2, name_size]
        idx += 2 + name_size
        idx,data=TagTypes[type][s,idx]
        hash[name] = data
      end
      [idx, hash]
    }
    TagTypes = {
      1 => TagByte,
      2 => TagShort,
      3 => TagInt,
      4 => TagLong,
      5 => TagFloat,
      6 => TagDouble,
      7 => TagByteArray,
      8 => TagString,
      9 => TagList,
      10 => TagHash,
      11 => TagIntArray
    }
    def self.parse sector
      TagHash[sector,0][1][""]
    end
  end
end

mc=MinecraftRegion.new "r.-1.-1.mca"
chunk = mc.chunk 0,8
p chunk #=> #<MinecraftRegion::Chunk:[-32, -24]>
p chunk.height_map[0][2] #=> 64
p chunk.block(0,2,63) #<MinecraftRegion::Chunk::Block:{x: 0, z: 2, y: 63, id: 12, sky_light: 0, block_light: 0, data: 0>

binding.pry
