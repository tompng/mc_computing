class MCWorld::Block
  attr_accessor :type, :sky_light, :block_light, :data
  def initialize t, s, b, d
    @type, @sky_light, @block_light, @data = t, s, b, d
  end
end
