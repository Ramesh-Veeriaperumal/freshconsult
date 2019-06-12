# The Admin::ApiTicketFieldsController class is responsible for creating create, update, delete of ticket fields.
module Admin
  class TicketFieldsController < CommonFieldsController
    include HelperConcern
    include TicketFieldsConstants

    def create
      ticket_field_delegator = DELEGATOR_CLASS.new(@item)
      if ticket_field_delegator.valid?
        @item.skip_populate_choices = true
        save_ticket_field_and_render
      else
        render_custom_errors(ticket_field_delegator, true)
      end
    end

    protected

      def requires_feature(*features)
        features_list = feature_name.present? ? Account.current.enabled_features_list : Account.current.all_launched_features
        if !features.all? { |x| features_list.include?(x) }
          render_request_error(:require_feature, 403, feature: features.join(',').titleize)
        elsif !Account.current.hipaa_and_encrypted_fields_enabled? && type.include?('encrypted_text')
          render_request_error(:require_feature, 403, feature: FeatureConstants::ENCRYPTED_FIELDS.join(',').titleize)
        else
          return
        end
      end

    private

      def feature_name
        FeatureConstants::TICKET_FIELDS
      end

      def escaped_fields
        TICKET_ESCAPE_FIELDS
      end

      def builder
        Builder::TicketFieldAndRelated
      end

      def scoper
        current_account.ticket_fields
      end

      def constants_class
        :TicketFieldsConstants.to_s.freeze
      end

      def nscname
        'admin_ticket_fields'
      end

      # Move to class if becomes complex.
      def sanitize_params
        escape_params(request_params)
        if type == 'nested_field'
          escape_nested_field_params
          escape_nested_choices(request_params['choices'])
        elsif CUSTOM_DROPDOWN_RELATED_FIELDS.include?(type)
          escape_dropdown_choices
        end
      end

      def escape_params(params)
        params.each do |attribute, value|
          params[attribute] = escape_value(value) if escaped_fields.include?(attribute) && value.is_a?(String)
        end
      end

      def escape_nested_choices(choice_params)
        choice_params.each do |choice_param|
          choice_param['value'] = escape_value(choice_param['value'])
          escape_nested_choices(choice_param['choices'])
        end
      end

      def escape_nested_field_params
        (request_params['nested_ticket_fields'] || [{}]).each do |nested_field_params|
          escape_params(nested_field_params)
        end
      end

      def escape_dropdown_choices
        request_params['choices'].each do |choice_param|
          choice_param['value'] = escape_value(choice_param['value'])
        end
      end

      def escape_value(input_string)
        input_string.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end

      def permissable_attributes
        fields = super
        fields | LABEL_FIELD.to_a if create?
      end

      def fetch_custom_field_attributes
        Helpdesk::TicketField::MODIFIABLE_CUSTOM_FIELD_TYPES.include?(type) ? get_fields('CUSTOM_FIELD_ONLY_ATTRIBUTES') : []
      end

      def required_type_given?
        type && Helpdesk::TicketField::MODIFIABLE_CUSTOM_FIELD_TYPES.include?(type)
      end

      def validate_request_given
        valid = super
        valid = validate_nested_fields if type == NESTED_FIELD && valid
        valid
      end

      def base_field_validation_object
        validation_klazz = TYPE_TO_VALIDATION_CLASS[type] || DEFAULT_VALIDATION_CLASS
        validation_klazz.new(request_params, nil)
      end

      def validate_nested_fields
        valid = true
        request_params['nested_ticket_fields'].each do |nested_field_param|
          nested_field_param.permit(*NESTED_TICKET_FIELD_ATTRIBUTES, [])
          valid = validate_nested_field(nested_field_param)
          break unless valid
        end
        valid
      end

      def validate_nested_field(nested_field_param)
        validation_object = nested_field_validation_object(nested_field_param.merge(type: type))
        valid = validation_object.valid?(action_name.to_sym)
        render_custom_errors(validation_object, true) unless valid
        valid
      end

      def nested_field_validation_object(nested_field_param)
        DEFAULT_VALIDATION_CLASS.new(nested_field_param, nil)
      end

      def save_ticket_field_and_render
        if @item.save
          @item.insert_at(request_params[:position]) if request_params[:position].present?
          render_201_with_location
        else
          render_custom_errors
        end
      end
  end
end
