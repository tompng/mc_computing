require 'zlib'
module MCWorld
end
require_relative 'tag'
require_relative 'chunk'
class MCWorld::World
  def to_s
    "#<#{self.class.name}:#{@file}>"
  end
  def inspect
    to_s
  end

  def initialize file
    @file = file
    @mcadata = File.binread file
    @sectors = []
    @chunks = {}
  end

  def []= x, z, chunk
    @chunks[[x,z]] = chunk
  end

  def [] x, z
    @chunks[[x,z]] ||= ::MCWorld::Chunk.new(data: parse_chunk(x,z))
  end

  private

  def parse_chunk x,z
    sector = Zlib.inflate compressed_sector(32*z+x)
    MCWorld::Tag::Hash.decode(sector,0)[1]['']['Level']
  end

  def compressed_sector i
    location = @mcadata[4*i,4].unpack('N')[0]
    sector = location>>8
    sector_size = location&0xff
    size, compress = @mcadata[sector*4096,5].unpack('Nc')
    @mcadata[sector*4096+5,size-1]
  end
end
