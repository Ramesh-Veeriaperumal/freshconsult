module Proactive
  class SimpleOutreachDelegator < BaseDelegator
    include CustomerImportConstants

    validate :email_config_presence, if: -> { @email_config_id }
    validate :attachment_id_presence, if: -> { @attachment_id }
    validate :attachment_file_format, if: -> { @attachment_file_name.present? &&  errors[:attachment_id].blank? }


    def initialize(record, options = {})
      super(record, options)
      @email_config_id = options[:email_config_id]
      @attachment_id = options[:attachment_id]
      @attachment_file_name = options[:attachment_file_name]
    end

    def email_config_presence
      email_config = Account.current.email_configs.where(id: @email_config_id).first
      if email_config.nil?
        errors[:email_config_id] << :"can't be blank"
      elsif !User.current.can_view_all_tickets? && Account.current.restricted_compose_enabled? && (User.current.group_ticket_permission || User.current.assigned_ticket_permission)
        accessible_email_config = email_config.group_id.nil? || User.current.agent_groups.exists?(group_id: email_config.group_id)
        errors[:email_config_id] << :inaccessible_value unless accessible_email_config
      end
    end

    def attachment_id_presence
      attachment = Account.current.attachments.where(id: @attachment_id, attachable_type: AttachmentConstants::STANDALONE_ATTACHMENT_TYPE).first
      unless attachment.present?
        errors[:attachment_id] << :invalid_list
        (error_options[:attachment_id] ||= {}).merge!({ list: @attachment_id })
      end
    end

    def attachment_file_format
      attachment = Account.current.attachments.where(id: @attachment_id, attachable_type: AttachmentConstants::STANDALONE_ATTACHMENT_TYPE).first
      original_filename = attachment.content.original_filename
      if !CSV_FILE_EXTENSION_REGEX.match(original_filename)
        errors[:attachment] = ErrorConstants::ERROR_MESSAGES[:invalid_format] % ACCEPTED_FILE_TYPE
      elsif original_filename != @attachment_file_name
        errors[:attachment_file_name] = :datatype_mismatch
        (error_options[:attachment_file_name] ||= {}).merge!(expected_data_type: original_filename, code: :invalid_field)
      end
    end
  end
end