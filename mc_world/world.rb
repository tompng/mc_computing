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

  def initialize file: nil, x: nil, z: nil
    if file
      @file = file
      @mcadata = File.binread file
    else
      @x, @z = x, z
    end
    @chunks = {}
  end

  def [] x, z
    if @file
      @chunks[[x,z]] ||= MCWorld::Chunk.new data: sector(32*z+x)
    else
      @chunks[[x,z]] ||= MCWorld::Chunk.new x: @x*32+x, z: @z*32+z
    end
  end

  private

  def sector i
    location = @mcadata[4*i,4].unpack('N')[0]
    sector = location>>8
    sector_size = location&0xff
    size, compress = @mcadata[sector*4096,5].unpack('Nc')
    @mcadata[sector*4096+5,size-1]
  end
end
