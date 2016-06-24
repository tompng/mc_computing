require_relative 'block_definition'
module MCWorld::Block
  module Data
    DOWN = Y_MINUS = 0
    UP = Y_PLUS = 1
    Z_MINUS = 2
    Z_PLUS = 3
    X_MINUS = 4
    X_PLUS = 5
    MASK = 8
  end
  class BlockData
    attr_reader :id, :data, :name
    def initialize name, id, data
      @name, @id, @data = name.to_s, id, data
    end
    def type;self[0];end
    def inspect;to_s;end
    def [] data;MCWorld::Block[id,data];end
    def to_s;"#{MCWorld::Block.name}::#{@name}";end
    def sky_light_transparent?
      MCWorld::Block::SkyLightTransparentBlockIds.include? id
    end
    Data.constants.each do |name|
      value = Data.const_get name
      define_method(name.to_s.downcase){self[value]}
    end
  end
  @blocks = {}
  def self.[] id, data=0
    @blocks[[id, data]] ||= (BlockData.new "Undefined[#{id},#{data}]", id, data if id > 0)
  end
  BlockDefinition.each do |name, value|
    id, data = value
    data ||= 0
    block = BlockData.new(name, id, data).freeze
    self.const_set name, block
    @blocks[[id, data]] = block
  end
  @blocks.keys.map(&:first).uniq.each do |id|
    main = 16.times.map{|data|@blocks[[id, data]]}.compact.first
    16.times do |data|
      @blocks[[id,data]] ||= BlockData.new "#{main.name}[#{data}]", id, data
    end
  end
end
