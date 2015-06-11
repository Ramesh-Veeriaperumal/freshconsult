class TicketsValidationHelper
  class << self
    def ticket_status_values(account)
      Helpdesk::TicketStatus.status_keys_by_name(account).values
    end

    def ticket_type_values(account)
      account.ticket_types_from_cache.collect(&:value)
    end

    def ticket_custom_field_keys(account)
      account.flexifields_with_ticket_fields_from_cache.collect(&:flexifield_alias)
    end

    # def ticket_drop_down_field_choices_by_key(account)
    #   account.custom_dropdown_fields_from_cache.collect {|y| [y.name, y.choices.flatten.uniq]}.to_h
    # end

    # Validates email for each value in the array attribute.
    def email_validator
      proc do |record, attr, value_array|
        if value_array.is_a? Array
          value_array.each do |value|
            unless valid_email?(value)
              record.errors.add attr, 'is not a valid email'
              break
            end
          end
        end
      end
    end

    def attachment_validator
      proc do |record, attr, value_array|
        if value_array.is_a? Array
          value_array.each do |value|
            unless value.is_a? ApiConstants::UPLOADED_FILE_TYPE
              record.errors.add attr, 'invalid_format'
              break
            end
          end
        end
      end
    end

    def valid_email?(value)
      # the commented line should be included if email regex is different for diff attributes
      # email_regex = ApiConstants.constants.include?"ApiConstants::#{attr}_REGEX" ? EMAIL_REGEX : const_value
      value =~ ApiConstants::EMAIL_REGEX
    end
  end
end
