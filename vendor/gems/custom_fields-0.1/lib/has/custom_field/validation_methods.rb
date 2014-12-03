module Has
  module CustomField

    module ValidationMethods

      VALIDATION_REGEX = {
        :custom_url => URI::regexp
      }

      private
        def presence_of_required_fields
          error_label = required_fields[:error_label]
          fields      = required_fields[:fields]

          fields.each do |field|
            field_value = send(field.name)
            self.errors.add( field.send(error_label), 
              I18n.t("#{self.class.to_s.downcase}.errors.required_field")) if (field_value.blank? || 
                                  field_value.is_a?(FalseClass)) # latter condition for checkbox alone
          end
        end

        def format_of_custom_fields
          error_label = validatable_custom_fields[:error_label]
          fields      = validatable_custom_fields[:fields]

          fields.each do |field|
            validation_method = "validate_format_of_#{field.field_type}"
            if respond_to?(validation_method, true)
              send("validate_format_of_#{field.field_type}", field, error_label) if send(field.name).present?
            else
              warn :"Validation Method #{validation_method} is not present for the #{field.field_type} - #{field.inspect}"
            end
          end
        end
        
        # def validate_format_of_custom_date field, error_label 
        #   add_error_to_self(field, error_label) unless send(field.name).is_a? DateTime
        # end
        # Doesn't work. Somewhere DateTime is already being parsed & no errors are being added if invalid

        def validate_format_of_custom_text field, error_label
          if field.regex.present?
            add_error_to_self(field, error_label) unless send(field.name) =~ field.regex
          end
        end

        def validate_format_of_custom_dropdown field, error_label
          add_error_to_self(field, error_label) unless field.choices.map(&:first).include? send(field.name)
        end

        def validate_format_of_custom_url field, error_label
          validate_format_using_regex field, error_label
        end

        def validate_format_using_regex field, error_label
          add_error_to_self(field, error_label) unless send(field.name) =~ VALIDATION_REGEX[field.field_type.to_sym]
        end

        def add_error_to_self field, error_label
          self.errors.add( field.send(error_label), 
            I18n.t("#{self.class.to_s.downcase}.errors.#{field.field_type}"))
        end

        def no_op field, error_label
        end

        alias_method :validate_format_of_custom_number, :no_op
        alias_method :validate_format_of_custom_survey_radio, :no_op
        alias_method :validate_format_of_custom_checkbox, :no_op
        alias_method :validate_format_of_custom_paragraph, :no_op
        alias_method :validate_format_of_custom_phone_number, :no_op
        alias_method :validate_format_of_custom_date, :no_op

    end
  
  end
end