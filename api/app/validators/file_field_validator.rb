class FileFieldValidator < ApiValidator
  include ErrorOptions

  private

    def message
      message_or_error_code
    end

    def error_code
      message_or_error_code
    end

    def invalid?
      (internal_values[:blank_when_required] = blank_when_required?) ||
        !value.nil? && (
          (internal_values[:datatype_mismatch] = datatype_mismatch?) ||
          (internal_values[:invalid_attachment] = invalid_attachment?) ||
          (internal_values[:invalid_image] = invalid_image?)
        )
    end

    def message_or_error_code
      if internal_values[:blank_when_required]
        :blank
      elsif internal_values[:datatype_mismatch]
        :datatype_mismatch
      elsif internal_values[:invalid_image]
        :invalid_image
      else
        :invalid_attachment
      end
    end

    def blank_when_required?
      options[:required] && value.blank?
    end

    def datatype_mismatch?
      if create?
        !value.is_a?(Integer)
      elsif value.is_a?(String) # possibly value from DB, because of mandatory field.
        return true if value_is_string_in_request?
        (@value = value.to_i) && (return false)
      else
        !value.is_a?(Integer)
      end
    end

    def invalid_attachment?
      @attachment = Account.current.attachments.where(id: value)[0]
      return true unless @attachment

      if create?
        !user_draft?
      else
        !(user_draft? || value == record.item.safe_send(attribute).to_i)
      end
    end

    def invalid_image?
      !@attachment.image?
    end

    def create?
      # item is ticket, which is not present in create operation
      record.item.nil?
    end

    def expected_data_type
      internal_values[:expected_data_type] = Integer if internal_values[:datatype_mismatch]
    end

    def skip_input_info?
      !internal_values[:datatype_mismatch]
    end

    def user_draft?
      @attachment.attachable_type == AttachmentConstants::STANDALONE_ATTACHMENT_TYPE && @attachment.attachable_id == User.current.id
    end

    def value_is_string_in_request?
      record.request_params[:custom_fields] && record.request_params[:custom_fields][attribute] && record.request_params[:custom_fields][attribute].is_a?(String)
    end
end
