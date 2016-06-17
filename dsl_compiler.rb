require_relative 'dsl'
module DSL
  module Operation
    def self.jump_label
      "label#{rand}"
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
        ops.push *expr(0, args)
      }
      ops
    end
    def self.expr stack, exp
      Operations[exp.op][stack, *exp.args]
    end
    Operations = {
      var: ->(stack, address){
        [[:set, [:memory, address], [:stack, stack]]]
      },
      const: ->(stack, value){
        [[:const_set, [:stack, stack], value]]
      },
      :'=' => ->(stack, a, b){
        [*expr(stack, b), [:set, [:stack, stack], [:memory, a.address]]]
      },
      getc: ->(stack){
        [[:getc], [:set, :value, [:stack, stack]]]
      },
      putc: ->(stack, v){
        [*expr(stack, v), [:set, [:stack, stack], :value], [:putc]]
      },
      exec_if: ->(stack, cond, *ifelse){
        if_block, else_block = ifelse
        ops = [*expr(stack, cond)]
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
      exec_while: ->(stack, cond, block){
        jump_start = jump_label
        jump_end = jump_label
        [
          [:label, jump_start],
          *expr(stack, cond),
          [:jump_if, nil, jump_end],
          *pre_compile(block),
          [:jump, jump_start],
          [:label, jump_end]
        ]
      },
      :[]= => ->(stack, a,i,v){
        if Const === i
          [*expr(stack, v), [:set, [:stack, stack], [:memory, a.address+v.value]]]
        else
          [
            *expr(stack, i),
            *expr(stack+1, v),
            [:set, [:stack, stack], :ref],
            [:set, [:stack, stack+1], :value],
            [:mem_write]
          ]
        end
      },
      :[] => ->(stack, a, i){
        if Const === i
          [[:set, [:memory, a.address+i.value], [:stack, stack]]]
        else
          [
            *expr(stack, i),
            [:set, [:stack, stack], :reg],
            [:set, [:memory, a.address], :value],
            [:+],
            [:set, :value, :ref],
            [:mem_read]
          ]
        end
      }
    }

    Op2.each do |op|
      Operations[op] ||= ->(stack, a, b){
        [
          *expr(stack, a),
          *expr(stack+1, b),
          [:set, [:stack, stack], :reg],
          [:set, [:stack, stack+1], :value],
          [op],
          [:set, :value, [:stack, stack]]
        ]
      }
    end

    Op1.each do |op|
      Operations[op] ||= ->(stack, a){
        [
          *expr(stack, a),
          [:set, [:stack, stack], :value],
          [op],
          [:set, :value, [:stack, stack]]
        ]
      }
    end
  end
end
__END__
DSL::Runtime.new{
  variable :x, :y, :z
  array a: 100
  var.a[var.x+var.y+var.z]=(var.z+'a')*var.x
  putc('c')
  var.x = (var.y + var.z)
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
