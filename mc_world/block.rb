require_relative 'block_definition'
module MCWorld::Block
  class BlockData
    attr_reader :id, :data, :name
    def initialize name, id, data
      @name, @id, @data = name.to_s, id, data
    end
    def type;self[0];end
    def inspect;to_s;end
    def [] data;MCWorld::Block[id,data];end
    def to_s;"#{MCWorld::Block.name}::#{@name}";end
  end
  @blocks = {}
  def self.[] id, data=0
    @blocks[[id, data]]
  end
  BlockDefinition.each do |name, value|
    id, data = value.split(':').map(&:to_i)
    data ||= 0
    block = BlockData.new(name, id, data).freeze
    self.const_set name, block
    @blocks[[id, data]] = block
  end
  @blocks.keys.map(&:first).uniq.each do |id|
    main = self[id,0]
    16.times do |data|
      @blocks[[id,data]] ||= BlockData.new "#{main.name}[#{data}]", id, data
    end
  end
end
