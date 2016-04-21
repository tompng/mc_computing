module MCWorld
  module Util
    def self.snake_case name
      name.gsub(/[A-Z]+/){|c|"_#{[c[0...-1],c[-1]].reject(&:empty?).join('_')}"}.downcase.gsub(/^_/,'')
    end
  end
  module NamedParenMethod
    class ParenMethodProxy
      def initialize ref, name
        @ref, @name = ref, name
      end
      def [] *key
        @ref.send "#{@name}_paren_get", *key
      end
      def []= *key, val
        @ref.send "#{@name}_paren_set", *key, val
      end
      def to_s
        "#{@ref}:#{@name}[]"
      end
      def inspect
        to_s
      end
    end
    def paren_method name
      class_eval %(
        def #{name}
          @#{name} ||= ParenMethodProxy.new self, '#{name}'
        end
      )
    end
  end
end