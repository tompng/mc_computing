require 'pry'
module DSL
  class Runtime
    attr_reader :current_block, :variables
    def self.define_custom_operation operations
      operations.each do |name, arity|
        raise if arity < 0 || arity > 2
        define_method name do |*args|
          raise if args.size != arity
          Exp.new self, :custom, name, *args.map{|v| Exp.to_exp(self, v).assign!}
        end
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
        @variables[name.to_s] = Var.new self, name, @address_index
        @address_index += 1
      end
    end
    def compile
      DSL::Operation.compile current_block
    end
    def array arrs
      arrs.each do |name, size|
        @variables[name.to_s] = Var.new self, name, @address_index
        @address_index += size
      end
    end
    def exec_if cond, &block
      if_block = Block.new
      else_block = Block.new
      args = [Exp.to_exp(self, cond).assign!, if_block]
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
      Exp.new self, :exec_if, lazy: args
      ifelse
    end
      def exec_while cond, &block
      while_block = Block.new
      with_block(while_block, &block)
      Exp.new self, :exec_while, Exp.to_exp(self, cond).assign!, while_block
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
      Const.new self, v
    end
    def var
      Variables.new @variables
    end
  end
  Op2 = %i(+ - * / % == != > >= < <= & | << >> ^)
  Op1 = %i(-@ +@ ! ~)
  class Exp
    attr_reader :op, :args, :runtime
    def assign!
      runtime.current_block.remove_operation self
      self
    end
    def self.to_exp runtime, exp
      Exp === exp ? exp : Const.new(runtime, exp)
    end
    def initialize runtime, op, *args, lazy: nil
      @runtime = runtime
      @op, @args = op, args
      @args = lazy if lazy
      runtime.current_block.add_operation self
    end
    def inspect
      to_s
    end
    Op2.each do |op|
      define_method(op){|val|
        Exp.new runtime, op, self.assign!, Exp.to_exp(runtime, val).assign!
      }
    end
    Op1.each do |op|
      define_method(op){Exp.new runtime, op, self.assign!}
    end
  end
  class Const < Exp
    attr_reader :value
    def initialize runtime, value
      case value
      when String
        raise unless value.size == 1
        @value = value.ord
      when Numeric
        @value = value.round
      when true
        @value = 1
      when false
        @value = 0
      else
        raise
      end
      super runtime, :const, @value
    end
  end
  class Var < Exp
    attr_reader :name, :address
    def initialize runtime, name, addr
      @name = name
      @runtime = runtime
      @address = addr
      super runtime, :var, addr
    end
    def to_s
      "var[#{@name}: #{@address}]"
    end
    def assign exp
      Exp.new runtime, :'=', self.assign!, Exp.to_exp(runtime, exp).assign!
    end
    def [] i
      Exp.new runtime, :[], self, Exp.to_exp(runtime, i).assign!
    end
    def []= i, v
      Exp.new runtime, :[]=, self.assign!, Exp.to_exp(runtime, i).assign!, Exp.to_exp(runtime, v).assign!
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
    def remove_operation op
      @operations = @operations.reject{|o|o.__id__ == op.__id__}
    end
  end
end
