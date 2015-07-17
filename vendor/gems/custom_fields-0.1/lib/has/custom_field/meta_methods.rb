module Has
  module CustomField

    module MetaMethods

      def respond_to? attribute, include_private_methods = false
        return false if [:to_ary, :after_initialize_without_slave, :to_a, :created_on, :updated_on].include?(attribute) || (attribute.to_s.include?("__initialize__") || attribute.to_s.include?("__callbacks"))
        # Rails.logger.debug "respond_to? #{self.class},#{attribute}"
        # Should include methods like to_a, created_on, updated_on as record_time_stamps is calling these mthds before any write operation
        return super(attribute, include_private_methods) if [:to_a, :created_on, :updated_on, :empty?].include?(attribute)
        super(attribute, include_private_methods) || custom_field_aliases.include?(attribute.to_s.chomp("=").chomp("?"))
      end

      def method_missing method, *args, &block
        begin
          super(method, *args, &block)
        rescue NoMethodError => e
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