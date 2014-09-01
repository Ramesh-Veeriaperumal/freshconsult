module Liquid
  class DocumentInFormat < Document

    XML                        = 1
    JAVASCRIPT_OBJECT_NOTATION = 2
    URL_ENCODED                = 3

    ContentOfVariable          = /^#{VariableStart}(.*)#{VariableEnd}$/o
    
    def initialize(tokens, content_type)
      @content_type = content_type      
      parse(tokens)
    end

    def create_variable(token)
      token.scan(ContentOfVariable) do |content|
        return Variable.new("#{content.first}#{escape_function @content_type}")
      end
      raise SyntaxError.new("Variable '#{token}' was not properly terminated 
        with regexp: #{VariableEnd.inspect} ")
    end

    def render_hash(context)
      render_all_as_hash(@nodelist, context)
    end

    def render_all_as_hash(list, context)
      output = []
      list.each do |token|
        # Break out if we have any unhanded interrupts.
        break if context.has_interrupt?

        begin
          # If we get an Interrupt that means the block must stop processing. An
          # Interrupt is any command that stops block execution such as {% break %} 
          # or {% continue %}
          if token.is_a? Continue or token.is_a? Break
            context.push_interrupt(token.interrupt)
            break
          end

          output << (token.respond_to?(:render) ? token.render(context) : token)
        rescue ::StandardError => e
          output << (context.handle_error(e))
        end
      end

      Hash[*output]
    end

    private

    def escape_function content_type
      case content_type
      when XML
        return ' | escape_markup_language'
      when JAVASCRIPT_OBJECT_NOTATION
        return ' | render_json_string_without_quotes'
      when URL_ENCODED
        return ' | do_percent_encoding'
      end
    end

  end
end