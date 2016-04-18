require 'zlib'
module MCWorld
end
require_relative 'tag'
require_relative 'chunk'
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
      @sectors = 1024.times.map{|i|
        sector_id, sector_count = @mcadata[4*i,4].unpack('N')[0].divmod(0x100)
        size, compress = @mcadata[sector_id*4096,5].unpack 'Nc'
        sector = @mcadata[sector_id*4096+5,size-1]
        sector unless sector.size.zero?
      }
      @timestamps = @mcadata[4096,4096].unpack 'N*'
    else
      @x, @z = x, z
      @timestamps = 4096.times.map{0}
      @sectors = 1024.times.map{nil}
    end
    @chunks = {}
  end

  def [] x, z
    if @file
      @chunks[[x,z]] ||= MCWorld::Chunk.new data: Zlib.inflate(@sectors[32*z+x])
    else
      @chunks[[x,z]] ||= MCWorld::Chunk.new x: @x*32+x, z: @z*32+z
    end
  end

  def release x, z
    @sections[32*z+x] = @chunks.delete([x,z]).encode
  end

  def encode
    out = []
    @sectors = 1024.times.map{|i|
      z,x=i.divmod 32
      chunk = @chunks[[x,z]]
      chunk ? chunk.encode : @sectors[i]
    }
    @sectors.each do |sector|
      sector_count = (sector.size+5).fdiv(4096).ceil
      sector_id = sector_index
      sector_index += sector_id
      out << [((sector_id<<8)|sector_count)].pack('N')
    end
    out << @timestamps.pack('N*')
    @sectors.each do |sector|
      out << sector
      out << 0.chr*(-sector.size%4096)
    end
    out.join
  end

end
