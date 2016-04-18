class MCWorld::Tag
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
      Byte.new(value.empty? ? End.type_id : type.type_id).encode(out)
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
