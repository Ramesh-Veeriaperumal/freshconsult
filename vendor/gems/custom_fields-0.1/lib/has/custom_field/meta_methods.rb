module Has
  module CustomField

    module MetaMethods

      def respond_to? attribute, include_private_methods = false
        super(attribute, include_private_methods) || custom_field_aliases.include?(attribute.to_s.chomp("=").chomp("?"))
      end

      def method_missing method, *args, &block
        begin
          super(method, *args, &block)
        rescue NoMethodError, NoMethodError => e
          Rails.logger.debug "#{self.class.name} method_missing :: args is #{args.inspect} and method:: #{method}"
          return custom_field_attribute(method, args) if custom_field_aliases.include?(
                                                                      method.to_s.chomp("=").chomp("?"))
          raise e
        end
      end

      private
        def custom_field_attribute attribute, args
          attribute = attribute.to_s
          return custom_field[attribute] unless attribute.include?("=")
          attribute = attribute.chomp!("=")
          args = args.first if !args.blank? && args.is_a?(Array)
          set_ff_value attribute, args
        end

        def set_ff_value ff_alias, ff_value
          @custom_field = nil   # resetting to reflect the assignments properly
          flexifield.set_ff_value ff_alias, ff_value
        end

    end

  end
end