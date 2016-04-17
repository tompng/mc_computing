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
    Tag::Hash.decode(sector,0)[1]['']['Level']
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
          cache[method] ||= MCNode.construct value.value, "#{name}:#{key}"
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

  class Chunk < MCNode
    attr_reader :height_map, :biomes
    def initialize hash
      hash = hash.value.dup
      @height_map = hash.delete('HeightMap').value.each_slice(16).to_a
      @biomes = hash.delete('Biomes').value.each_slice(16).to_a
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

  class Tag
    class Type
      attr_accessor :value
      def initialize value;@value = value;end
      def inspect;to_s;end
      def to_s;"#<#{self.class.name}:#{value}>";end
      @@types = []
      def self.[] id
        @@types[id]
      end
      def self.extend id: nil, option: nil, encode: nil, decode: nil
        @@types[id] = Class.new(Type).tap do |klass|
          klass.define_singleton_method(:type_id){id}
          klass.class_eval &option if option
          klass.send :define_method, :encode, &encode
          klass.define_singleton_method :decode, &decode
        end
      end
    end
    packable_klass = ->(id, type, size){
      Type.extend(
        id: id,
        encode: ->(out){
          out << [value].pack(type)
        },
        decode: ->(s, idx){
          [idx+size, new(s[idx,size].unpack(type)[0])]
        }
      )
    }
    End = Type.extend(id: 0, encode: ->(out){}, decode: ->(s, idx){[idx, nil]})
    Float = packable_klass[5,'g',4]
    Double = packable_klass[6,'G',8]
    Byte = packable_klass[1,'c', 1]
    Short = packable_klass[2,'s>', 2]
    Int = packable_klass[3,'l>',4]
    Long = Type.extend(
      id: 4,
      encode: ->(out){
        v = value&((1<<64)-1)
        out << [v>>32,v&((1<<32)-1)].pack('NN')
      },
      decode: ->(s, idx){
        a, b = s[idx,8].unpack('NN')
        n=(a<<32)|b
        n -= 1<<64 if n >= 1<<63
        [idx+8, new(n)]
      }
    )

    key_accessible = ->(klass){
      klass.send(:define_method, :[]){|i|value[i]}
      klass.send(:define_method, :[]=){|i,v|value[i]=v}
    }
    packable_array_klass = ->(id, size_klass, per_item, type=nil){
      Type.extend(
        id: id,
        option: key_accessible,
        encode: ->(out){
          size_klass.new(value.size).encode(out)
          out << (type ? value.pack(type) : value)
        },
        decode: ->(s, idx){
          idx, size = size_klass.decode s, idx
          value = s[idx, size.value*per_item]
          [idx + size.value*per_item, new(type ? value.unpack(type) : value)]
        }
      )
    }
    String = packable_array_klass[8, Short, 1]
    ByteArray = packable_array_klass[7, Int, 1, 'c*']
    IntArray = packable_array_klass[11, Int, 4, 'l>*']

    List = Type.extend(
      id: 9,
      option: ->(klass){
        klass.send :attr_reader, :type
        klass.send(:define_method, :initialize){|type,value|@type,@value=type,value}
        key_accessible[klass]
      },
      encode: ->(out){
        Byte.new(type.type_id).encode(out)
        Int.new(value.size).encode(out)
        value.each{|v|v.encode(out)}
      },
      decode: ->(s, idx){
        idx, type_id = Byte.decode s, idx
        idx, size = Int.decode s, idx
        list = []
        size.value.times.each{|i|
          idx, data = Type[type_id.value].decode s, idx
          list << data
        }
        [idx, new(Type[type_id.value], list)]
      }
    )
    Hash = Type.extend(
      id: 10,
      option: ->(klass){
        key_accessible[klass]
        klass.send(:define_method, :to_s){
          "#<#{self.class.name}:[#{value.keys.join(', ')}]>"
        }
      },
      encode: ->(out, end_flag: true){
        value.each do |key, val|
          Byte.new(val.class.type_id).encode(out)
          String.new(key).encode(out)
          val.encode(out)
        end
        out << 0.chr if end_flag
      },
      decode: ->(s, idx){
        hash = {}
        loop do
          idx, type = Byte.decode s, idx
          break if type.value.nil? || type.value.zero?
          idx, name = String.decode s, idx
          idx, data = Type[type.value].decode s, idx
          hash[name.value] = data
        end
        [idx, new(hash)]
      }
    )
    def self.encode hash
      obj = Hash.new '' => hash
      out = []
      obj.encode(out, end_flag: false)
      out.join
    end
    def self.decode section
      Hash.decode(section, 0)[1]['']
    end
  end
end

mc=MinecraftRegion.new "r.-1.-1.mca"
chunk = mc.chunk 0,8
p chunk #=> #<MinecraftRegion::Chunk:[-32, -24]>
p chunk.height_map[0][2] #=> 64
p chunk.block(0,2,63) #<MinecraftRegion::Chunk::Block:{x: 0, z: 2, y: 63, id: 12, sky_light: 0, block_light: 0, data: 0>
# binding.pry
p :AAA
sec=mc.send :decode_sector, 256;sec.size
hoge = MinecraftRegion::Tag.decode sec
sec2 = MinecraftRegion::Tag.encode hoge
binding.pry