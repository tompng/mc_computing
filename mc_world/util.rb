module MCWorld
  module Util
    def self.snake_case name
      name.gsub(/[A-Z]+/){|c|"_#{[c[0...-1],c[-1]].reject(&:empty?).join('_')}"}.downcase.gsub(/^_/,'')
    end
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