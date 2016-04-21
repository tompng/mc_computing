module MCWorld::TileEntity
  class Entities
    def initialize base_x, base_z, tiles
      @base_x, @base_z = base_x, base_z
      @tile_table = {}
      tiles.each do |tile|
        key = [
          tile['x'].value - base_x,
          tile['z'].value - base_z,
          tile['y'].value
        ]
        @tile_table[key] = tile
      end
    end
    def [] x, z, y
      @tile_table[[x, z, y]]
    end
    def []= x, z, y, val
      key = [x, z, y]
      unless val
        @tile_table.delete key
        return
      end
      (val['x'] ||= MCWorld::Tag::Int.new(0)).value = @base_x + x
      (val['z'] ||= MCWorld::Tag::Int.new(0)).value = @base_z + z
      (val['y'] ||= MCWorld::Tag::Int.new(0)).value = y
      @tile_table[key] = val
    end
    def encode_data
      MCWorld::Tag::List.new MCWorld::Tag::Hash, @tile_table.values
    end
  end

  module Chest
    def self.LootChest type, lock: '', seed: rand(0...1<<64)
      MCWorld::Tag::Hash.new(
        'id' => MCWorld::Tag::String.new('Chest'),
        'LootTable' => MCWorld::Tag::String.new(type),
        'Lock' => MCWorld::Tag::String.new(lock),
        'LootTableSeed' => MCWorld::Tag::Long.new(seed)
      )
    end
    %w(abandoned_mineshaft desert_pyramid end_city_treasure igloo_chest jungle_temple nether_bridge simple_dungeon spawn_bonus_chest stronghold_corridor stronghold_crossing stronghold_library village_blacksmith).each do |type|
      name = type
      name += '_chest' unless name =~ /_chest$/
      define_singleton_method name do |*args|
        LootChest "minecraft:chests/#{type}", *args
      end
    end
    def self.chest lock: '', items: []
      slot_items = 27.times.map{|slot|
        item = items[slot]
        next unless item
        item = {id: item} if String === item
        MCWorld::Tag::Hash.new(
          'id' => MCWorld::Tag::String.new(item[:id]),
          'Slot' => MCWorld::Tag::Byte.new(slot),
          'Count' => MCWorld::Tag::Byte.new(item[:count]||1),
          'Damage' => MCWorld::Tag::Short.new(item[:damage]||0),
        )
      }.compact
      MCWorld::Tag::Hash.new(
        'id' => MCWorld::Tag::String.new('Chest'),
        'Lock' => MCWorld::Tag::String.new(lock),
        'Items' => MCWorld::Tag::List.new(MCWorld::Tag::Hash, slot_items)
      )
    end
  end
end
