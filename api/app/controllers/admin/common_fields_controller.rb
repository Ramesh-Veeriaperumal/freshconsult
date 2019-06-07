module Admin
  class CommonFieldsController < ApiApplicationController
    def request_params
      @request_params ||= params[cname]
    end

    def type
      @type ||= begin
        required_type = request_params['type'] || @item.try(:field_type)
        required_type.present? ? required_type.to_s : nil
      end
    end

    # contains the unexposed action methods for controller and non extensible. Please move it to private if you want it to be extensible.
    protected

      def validate_params
        if required_type_given?
          request_params.permit(*permissable_attributes, [])
        end
        validate_request_given
      end

      def permissable_attributes
        get_fields(basic_string) | get_fields(type_string) | get_fields(action_string) | fetch_custom_field_attributes
      end

      def get_fields(string)
        constants_klass.const_defined?(string) ? constants_klass.const_get(string) : []
      end

    # private contains extensible methods that needs to be overwritten.
    private

      def escaped_fields
        # overwrite this to provide the escaped_fields.
      end

      def builder
        # overwrite this to provide the aggregator.
      end

      def basic_string
        'BASIC_ATTRIBUTES'
      end

      def type_string
        "#{type.upcase}_ATTRIBUTES"
      end

      def action_string
        "#{action_name.upcase}_ATTRIBUTES"
      end

      def fetch_custom_field_attributes
        # extend this to get attributes only for custom field only for create and update, not for default fields.
      end

      def required_type_given?
        # extend this for checking type presence.
      end

      def validate_request_given
        validate_base_field
      end

      # non extendable
      def validate_base_field
        validation_object = base_field_validation_object
        valid = validation_object.valid?(action_name.to_sym)
        render_custom_errors(validation_object, true) unless valid
        valid
      end

      def base_field_validation_object
        # extend this to get the name of base validator.
      end

      # non extendable
      def build_object
        @item = builder.new(request_params, current_account).build
      end
  end
end
