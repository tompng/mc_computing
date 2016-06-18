require 'pry'
module DSL
  class Runtime
    attr_reader :current_block, :variables
    def self.define_custom_expression name, arity: 0
      raise if arity < 0 || arity > 2
      define_method name do |*args|
        raise if args.size != arity
        Exp.new :custom, name, *args.map{|v| Exp.to_exp(v)}
      end
    end
    def self.define_custom_statement name, arity: 0
      raise if arity < 0 || arity > 2
      define_method name do |*args|
        raise if args.size != arity
        current_block.add_operation Exp.new :custom, name, *args.map{|v| Exp.to_exp(v)}
        nil
      end
    end
    def with_block block
      prev = @current_block
      @current_block = block
      yield
      @current_block = prev
    end
    def initialize &block
      @variables = {}
      @address_index = 0
      @current_block = Block.new
      instance_eval &block
    end
    def variable *vars
      vars.each do |name|
        @variables[name.to_s] = Var.new name, @address_index, self
        @address_index += 1
      end
    end
    def compile
      DSL::Operation.compile current_block
    end
    def array arrs
      arrs.each do |name, size|
        @variables[name.to_s] = Var.new name, @address_index, self
        @address_index += size
      end
    end
    def exec_if cond, &block
      if_block = Block.new
      else_block = Block.new
      args = [Exp.to_exp(cond), if_block]
      with_block(if_block, &block)
      ifelse = Object.new
      rt = self
      ifelse.define_singleton_method :else  do |&block|
        args.push else_block
        rt.with_block(else_block, &block)
      end
      ifelse.define_singleton_method :elsif do |cond, &block|
        args.push else_block
        elsif_block = nil
        rt.with_block(else_block){
          elsif_block = rt.exec_if(cond, &block)
        }
        elsif_block
      end
      current_block.add_operation Exp.new :exec_if, lazy: args
      ifelse
    end
      def exec_while cond, &block
      while_block = Block.new
      with_block(while_block, &block)
      current_block.add_operation Exp.new :exec_while, Exp.to_exp(cond), while_block
      nil
    end
    class Variables < BasicObject
      def initialize table
        @table = table
      end
      def method_missing name, *args
        if name[-1] == '='
          v = @table[name[0...-1]]
          super unless v
          v.assign *args
        else
          v = @table[name.to_s]
          super unless v
          v
        end
      end
    end
    def const v
      Const.new v
    end
    def var
      Variables.new @variables
    end
  end
  Op2 = %i(+ - * / % == != > >= < <= & | << >>)
  Op1 = %i(-@ +@ !)
  class Exp
    attr_reader :op, :args
    def self.to_exp exp
      Exp === exp ? exp : Const.new(exp)
    end
    def initialize op, *args, lazy: nil
      @op, @args = op, args
      @args = lazy if lazy
    end
    def inspect
      to_s
    end
    Op2.each do |op|
      define_method(op){|val|Exp.new op, self, Exp.to_exp(val)}
    end
    Op1.each do |op|
      define_method(op){Exp.new op, self}
    end
  end
  class Const < Exp
    attr_reader :value
    def initialize value
      case value
      when String
        raise unless value.size == 1
        @value = value.ord
      when Numeric
        @value = value.round
      else
        raise
      end
      super :const, @value
    end
  end
  class Var < Exp
    attr_reader :name, :address
    def initialize name, addr, runtime
      @name = name
      @runtime = runtime
      @address = addr
      super :var, addr
    end
    def to_s
      "var[#{@name}: #{@address}]"
    end
    def assign exp
      @runtime.current_block.add_operation Exp.new(:'=', self, Exp.to_exp(exp))
    end
    def [] i
      Exp.new :[], self, Exp.to_exp(i)
    end
    def []= i, v
      @runtime.current_block.add_operation Exp.new(:[]=, self, Exp.to_exp(i), Exp.to_exp(v))
    end
  end
  class Block
    attr_reader :operations
    def initialize &block
      @operations = []
    end
    def add_operation op
      @operations << op
    end
  end
end
