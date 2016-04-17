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
    @chunks = []
  end

  def chunk i
    @chunks[i] ||= MCNode.new(parse_chunk(i), 'Chunk')
  end

  def parse_chunk i
    sector = decode_sector i
    TagParser.parse(sector)['Level']
  end

  private
  def decode_sector i
    location = @mcadata[4*i,4].unpack('N')[0]
    sector = location >> 8
    sector_size = location & 0xff
    size, compress = @mcadata[sector*4096,5].unpack('Nc')
    Zlib.inflate @mcadata[sector*4096+5,size - 1]
  end

  class MCNode
    def initialize hash, name
      define_singleton_method(:to_h){hash}
      values = hash.map do |key, value|
        [MCNode.snake_case(key), MCNode.construct(value, "#{name}::#{key}")]
      end
      define_singleton_method(:to_s){"#<#{name}:[#{values.map(&:first).join(', ')}]>"}
      values.each do |method, value|
        define_singleton_method(method){value}
      end
    end
    def inspect;to_s;end
    def self.snake_case name
      name.gsub(/[A-Z]+/){|c|"_#{[c[0...-1],c[-1]].reject(&:empty?).join('_')}"}.downcase.gsub(/^_/,'')
    end
    def self.single_name name
      case name
      when /ies$/
        name[0...-3]+'y'
      when /s$/
        name[0...-1]
      else
        name
      end
    end
    def self.construct value, name
      case value
      when Hash
        new value, name
      when Array
        classname = single_name(name)
        value.map{|v|construct v, classname}
      else
        value
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
chunk = mc.chunk 256
p chunk #=> #<Chunk:[light_populated, z_pos, height_map, sections, ...]>
p chunk.sections #=> [#<Chunk::Section:[blocks, sky_light, y, block_light, data]>,...]
p chunk.height_map #=> [63,63,64,64,64,64,59,59,60,...]

binding.pry
1024.times.map{|i|
  mc.chunk(i);p i
}