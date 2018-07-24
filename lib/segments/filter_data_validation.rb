module Segments
  class FilterDataValidation
    include FilterDataConstants

    def initialize(query_hash, type = CONTACT)
      @query_hash = query_hash
      @current_account = Account.current
      @all_fields = {}
      @segment_type = type
    end

    def valid?
      condition_data = @query_hash.is_a?(Hash) ? @query_hash.values : @query_hash
      return false if condition_data.blank?
      segregate_default_and_custom_fields
      condition_data.all? do |data|
        check_field_type(data)
      end
    end

    def fields_info
      segregate_default_and_custom_fields('id')
      @all_fields
    end

    private

      def segment_fields
        @segment_fields ||= if contact_segment?
                              @current_account.contact_form.contact_fields_from_cache
                            else
                              @current_account.company_form.company_fields_from_cache
                            end
      end

      def segregate_default_and_custom_fields(obj_id = '')
        segment_fields.each do |segment_field|
          if allowed_default_fields?(segment_field)
            @all_fields[segment_field.name] = (obj_id.present? ? segment_field.id : DEFAULT_FIELD)
          elsif allowed_custom_field?(segment_field)
            @all_fields[segment_field.name] = (obj_id.present? ? segment_field.id : CUSTOM_FIELD)
          end
        end
        @all_fields['created_at'] = DEFAULT_FIELD
      end

      def allowed_custom_field?(segment_field)
        return false if segment_field.column_name.eql?(DEFAULT_FIELD)
        return false unless segment_field.column_name.starts_with?(*ALLOWED_CUSTOM_FIELDS)
        return segment_field.choices.any? if segment_field.column_name.starts_with?(STRING_FIELD)
        true
      end

      def allowed_default_fields?(segment_field)
        segment_field.column_name.eql?(DEFAULT_FIELD) && allowed_default_field_list.include?(segment_field.name)
      end

      def allowed_default_field_list
        contact_segment? ? ALLOWED_CONTACT_DEFAULT_FIELDS : ALLOWED_COMPANY_DEFAULT_FIELDS
      end

      def check_field_type(data)
        (data['type'].eql?(DEFAULT_FIELD) && @all_fields[data['condition']].eql?(DEFAULT_FIELD)
        ) || (data['type'].eql?(CUSTOM_FIELD) && @all_fields["cf_#{data['condition']}"].eql?(CUSTOM_FIELD))
      end

      def contact_segment?
        CONTACT.include?(@segment_type)
      end
  end
end
