module MCWorld
  module Util
    def self.snake_case name
      name.gsub(/[A-Z]+/){|c|"_#{[c[0...-1],c[-1]].reject(&:empty?).join('_')}"}.downcase.gsub(/^_/,'')
    end
  end
  class Heap
    def initialize data=[], &compare_by
      if compare_by
        @table = {}
        @compare_by = compare_by
        @heap = data.map(&compare_by).uniq.sort
        data.each do |value|
          key = compare_by[value]
          (@table[key] ||= []) << value
        end
      else
        @heap = data.sort
      end
    end
    def << data
      if @compare_by
        key = @compare_by[data]
        if @table[key]
          @table[key] << data
          return data
        end
        @table[key] = [data]
        value = key
      else
        value = data
      end
      index = @heap.size
      @heap[index] = value
      while index > 0
        pindex = (index-1)/2
        pvalue = @heap[pindex]
        break if pvalue < value
        @heap[pindex], @heap[index] = value, pvalue
        index = pindex
      end
      data
    end
    def first
      value = @heap[0]
      return @table[value].first if value && @compare_by
      value
    end
    def pop
      return nil if @heap.empty?
      index = 0
      value = @heap[index]
      if @compare_by
        list = @table[value]
        data = list.shift
        return data unless list.empty?
        @table.delete value
      else
        data = value
      end
      value = @heap.pop
      return data if @heap.empty?
      @heap[index] = value
      while true
        lindex, rindex = 2*index+1, 2*index+2
        left, right = @heap[lindex], @heap[rindex]
        break unless left
        cindex, cvalue = !right || left < right ? [lindex, left] : [rindex, right]
        break unless value > cvalue
        @heap[index], @heap[cindex] = cvalue, value
        index = cindex
      end
      data
    end
    def to_s;"#<#{self.class.name}:0x#{(object_id*2).to_s(16)}[#{@heap.size}]>";end
    def inspect;to_s;end
    def empty?;@heap.empty?;end
  end
  module NamedParenMethod
    class ParenMethodProxy
      def initialize ref, name, get: nil, set: nil
        @ref, @name = ref, name
        define_singleton_method(:[]){|*args|@ref.instance_exec *args, &get} if get
        define_singleton_method(:[]=){|*args|@ref.instance_exec *args, &set} if set
      end
      def to_s
        "#{@ref}:#{@name}[]"
      end
      def inspect
        to_s
      end
    end
    def define_paren_method name, option
      ivname = "@#{name}"
      define_method name do
        instance_variable_get(ivname) || instance_variable_set(ivname, ParenMethodProxy.new(self, name, option))
      end
    end
  end
end