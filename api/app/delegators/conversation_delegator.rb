class ConversationDelegator < BaseDelegator

  attr_accessor :email_config_id, :cloud_file_attachments

  validate :validate_agent_emails, if: -> { note? && to_emails.present? && attr_changed?('to_emails', schema_less_note)}

  validate :validate_from_email, if: -> { email_conversation? && from_email.present? && attr_changed?('from_email', schema_less_note)}

  validate :validate_agent_id, if: -> { fwd_email? && user_id.present? && attr_changed?('user_id')}

  validate :validate_cloud_files, if: -> { @cloud_file_ids }

  def initialize(record, options = {})
    options[:attachment_ids] = skip_parent_attachments(options) if options[:attachment_ids]
    super(record, options)
    @cloud_file_ids = options[:cloud_file_ids]
    retrieve_cloud_files if @cloud_file_ids
  end

  def validate_agent_emails
    invalid_emails = to_emails - Account.current.agents_from_cache.map { |x| x.user.email }
    unless invalid_emails.empty?
      errors[:notify_emails] << :invalid_agent_emails
      (self.error_options ||= {}).merge!(notify_emails: { invalid_emails: "#{invalid_emails.join(', ')}" })
    end
  end

  def validate_from_email
  	email_config = Account.current.email_configs.where(reply_email: from_email).first
    if email_config
      self.email_config_id = email_config.id
    else
      errors[:from_email] << :"can't be blank"
    end
  end

  def validate_agent_id
    user = Account.current.agents_details_from_cache.find { |x| x.id == user_id }
    errors[:agent_id] << :"is invalid" unless user
  end

  def validate_cloud_files
    invalid_file_ids = @cloud_file_ids - @cloud_file_attachments.map(&:id)
    if invalid_file_ids.any?
      errors[:cloud_file_ids] << :invalid_list
      (self.error_options ||= {}).merge!({ cloud_file_ids: { list: "#{invalid_file_ids.join(', ')}" } })
    end
  end

  private

    def skip_parent_attachments(options)
      return options[:attachment_ids] if options[:include_original_attachments]
      options[:attachment_ids] - (options[:parent_attachments] || []).map(&:id)
    end

    def retrieve_cloud_files
      @cloud_file_attachments = notable.cloud_files.where(id: @cloud_file_ids)
    end
end
