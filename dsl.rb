require 'pry'
module DSL
  class Runtime
    attr_reader :current_block, :variables
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
    def putc val
      current_block.add_operation [:putc, val]
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
      op = [:exec_if, cond, if_block]
      with_block(if_block, &block)
      ifelse = Object.new
      rt = self
      ifelse.define_singleton_method :else  do |&block|
        op.push else_block
        rt.with_block(else_block, &block)
      end
      current_block.add_operation op
      ifelse
    end
    def exec_while cond, &block
      while_block = Block.new
      with_block(while_block, &block)
      current_block.add_operation [:exec_while, cond, while_block]
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
    def var
      Variables.new @variables
    end
  end
  class Calc
    attr_accessor :op, :args
    def initialize *args
      @op, *@args = args
    end
    def inspect;to_s;end
    def to_s
      "calc[#{@op} #{@args.join ' '}]"
    end
  end
  Op2 = [:+, :-, :*, :==, :>, :>=, :<, :<=, :[]]
  class Var
    attr_reader :address
    def initialize name, address, runtime
      @name = name
      @runtime = runtime
      @address = address
    end
    def inspect;to_s;end
    def to_s
      "var[#{@name}: #{@address}]"
    end
    def assign val
      validates_var_const_calc! val
      @runtime.current_block.add_operation [:'=', self, val]
    end

    def validates_var_const_calc! val
      raise 'var/const/calc' unless String === val || Fixnum === val || Var === val || Calc === val
    end
    def validates_var_or_const! val
      raise 'var or const / use tmp var' unless String === val || Fixnum === val || Var === val
    end

    Op2.each do |op|
      define_method(op){|v|validates_var_or_const! v;Calc.new op, self, v}
    end
    [:-@, :+@, :!].each do |op|
      define_method(op){Calc.new op, self}
    end
    def []= i, v
      validates_var_or_const! i
      validates_var_or_const! v
      @runtime.current_block.add_operation [:[]=, self, i, v]
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

  def compile

  end
  module Operation
    def self.const_to_i v
      if String === v
        raise unless v.size == 1
        v.ord
      else
        v.to_i
      end
    end
    def self.jump_label
      @jump_label ||= 'aaaa'
      (@jump_label = @jump_label.next).to_sym
    end
    def self.compile block
      pre_compiled = pre_compile block
      index = 0
      stripped = []
      label_table = {}
      pre_compiled.each do |command|
        if command.first == :label
          label_table[command.last] = stripped.size
        else
          stripped << command
        end
      end
      stripped.map{|command|
        op, *args = command
        if op == :jump || op == :jump_if
          [op, *args.map{|label|label_table[label]}]
        else
          command
        end
      }
    end
    def self.pre_compile block
      ops = []
      block.operations.each{|args|
        ops.push *expr(args)
      }
      ops
    end
    def self.expr args
      if Var === args
        [[:read, args.address]]
      elsif Calc === args
        Operations[args.op][*args.args]
      elsif Array === args
        Operations[args.first][*args.drop(1)]
      else
        [[:val_set, const_to_i(args)]]
      end
    end
    Operations = {
      :'=' => ->(a, b){
        [*expr(b), [:write, a.address]]
      },
      putc: ->(v){
        [*expr(v), [:putc]]
      },
      exec_if: ->(cond, *ifelse){
        if_block, else_block = ifelse
        ops = []
        ops.push *expr(cond)
        jump_else = jump_label
        jump_end = jump_label
        if else_block
          ops << [:jump_if, nil, jump_else]
        else
          ops << [:jump_if, nil, jump_end]
        end
        ops.push *pre_compile(if_block)
        if else_block
          ops << [:jump, jump_end]
          ops << [:label, jump_else]
          ops.push *pre_compile(else_block)
        end
        ops << [:label, jump_end]
        ops
      },
      exec_while: ->(cond, block){
        jump_start = jump_label
        jump_end = jump_label
        [
          [:label, jump_start],
          *expr(cond),
          [:jump_if, nil, jump_end],
          *pre_compile(block),
          [:jump, jump_start],
          [:label, jump_end]
        ]
      },
      :[]= => ->(a,i,v){
        if Var === i
          [
            *expr(i),
            [:ref_set],
            *expr(v),
            [:mem_write]
          ]
        else
          [
            *expr(v),
            [:write, a.address+const_to_i(i)]
          ]
        end
      },
      :[] => ->(a,i){
        if Var === i || Calc === i
          [
            *expr(i),
            [:reg_set],
            [:read, a.address],
            [:+],
            [:ref_set],
            [:mem_read]
          ]
        else
          [[:read, a.address+const_to_i(i)]]
        end
      }
    }

    Op2.each do |op|
      Operations[op] ||= ->(a,b){
        [
          [:read, a.address],
          [:reg_set],
          (Var === b ? [:read, b.address] : [:val_set, const_to_i(b)]),
          [op]
        ]
      }
    end
  end
end
__END__
DSL::Runtime.new{
  variable :x, :y, :z
  array a: 100
  var.a[0]='a'
  putc('c')
  var.x = var.y + var.z
  exec_if(var.x==var.y){
    exec_if(var.x > 3){
      var.x = 4
    }
  }.else{
    var.z = 3
  }
  exec_while(var.z < 10){
    var.z += 1
    putc var.z
    var.z = var.a[var.y]
    var.a[var.y] = var.z
    putc var.x+var.y
  }
  compiled = DSL::Operation.compile current_block
  binding.pry
}
