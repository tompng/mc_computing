require 'zlib'
module MCWorld
end
require_relative 'util'
require_relative 'tag'
require_relative 'block'
require_relative 'chunk'
require_relative 'tile_entity'

class MCWorld::World
  attr_reader :file, :mcadata, :sectors
  def to_s
    "#<#{self.class.name}:#{@file}>"
  end
  def inspect
    to_s
  end

  def initialize file: nil, x: nil, z: nil
    @sector_order = 1024.times.to_a
    if file
      @file = file
      @mcadata = File.binread file
      @sectors = 1024.times.map do |i|
        sector_id, sector_count = @mcadata[4*i,4].unpack('N')[0].divmod(0x100)
        size, compress = @mcadata[sector_id*4096,5].unpack 'Nc'
        @mcadata[sector_id*4096+5,size-1] unless size.zero? || sector_id.zero?
      end
      @timestamps = @mcadata[4096,4096].unpack 'N*'
      if /r\.(?<xs>\d)\.(?<zs>\d)\.mca/ =~ file
        x ||= xs.to_i
        z ||= zs.to_i
      end
    else
      @timestamps = 1024.times.map{0}
      @sectors = 1024.times.map{nil}
    end
    @x, @z = x, z
    @chunks = {}
  end

  def []= x, z, y, block
    chunk(x/16, z/16)[x%16,z%16,y]=block
  end
  def [] x, z, y
    chunk(x/16, z/16)[x%16,z%16,y]
  end
  extend MCWorld::NamedParenMethod
  define_paren_method(
    :tile_entities,
    get: ->(x,z,y){chunk(x/16, z/16).tile_entities[x%16, z%16, y]},
    set: ->(x,z,y,v){chunk(x/16, z/16).tile_entities[x%16, z%16, y] = v}
  )
  define_paren_method(
    :height_map,
    get: ->(x,z){chunk(x/16, z/16).height_map[x%16][z%16]},
    set: ->(x,z,v){chunk(x/16, z/16).height_map[x%16][z%16] = v},
  )
  def chunk x, z
    chunk = @chunks[[x,z]]
    return chunk if chunk
    if sector = @sectors[32*z+x]
      @chunks[[x,z]] = MCWorld::Chunk.new data: Zlib.inflate(sector)
    else
      @chunks[[x,z]] = MCWorld::Chunk.new x: @x*32+x, z: @z*32+z
    end
  end

  def release_chunk x, z
    @sections[32*z+x] = @chunks.delete([x,z]).encode
  end

  def encode
    out = []
    @sectors = 1024.times.map{|i|
      z,x=i.divmod 32
      chunk = @chunks[[x,z]]
      chunk ? Zlib.deflate(chunk.encode) : @sectors[i]
    }
    sector_index = 2
    @sectors.each do |sector|
      unless sector
        out << [0].pack('N')
        next
      end
      sector_count = (sector.size+5).fdiv(4096).ceil
      sector_id = sector_index
      sector_index += sector_count
      out << [((sector_id<<8)|sector_count)].pack('N')
    end
    out << @timestamps.pack('N*')
    @sectors.compact.each do |sector|
      compress = 2
      out << [sector.size+1, compress].pack('Nc')
      out << sector
      out << 0.chr*(-(sector.size+5)%4096)
    end
    out.join
  end

end
