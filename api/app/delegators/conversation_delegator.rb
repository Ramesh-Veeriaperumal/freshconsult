class ConversationDelegator < ConversationBaseDelegator

  attr_accessor :email_config_id, :email_config, :cloud_file_attachments

  validate :validate_agent_emails, if: -> { note? && to_emails.present? && attr_changed?('to_emails', schema_less_note)}

  validate :validate_from_email, if: -> { email_conversation? && from_email.present? && attr_changed?('from_email', schema_less_note)}

  validate :validate_agent_id, if: -> { fwd_email? && user_id.present? && attr_changed?('user_id')}

  validate :validate_tracker_id, if: -> { broadcast_note? }

  validate :validate_cloud_file_ids, if: -> { @cloud_file_ids }

  validate :validate_application_id, if: -> { cloud_files.present? }

  validate :validate_send_survey, unless: -> { send_survey.nil? }

  validate :validate_unseen_replies, on: :reply, if: :traffic_cop_required?
  validate :validate_unseen_replies_for_public_notes, on: :create, if: -> { public_note? and traffic_cop_required? }

  def initialize(record, options = {})
    options[:attachment_ids] = skip_existing_attachments(options) if options[:attachment_ids]
    super(record, options)
    @cloud_file_ids = options[:cloud_file_ids]
    retrieve_cloud_files if @cloud_file_ids
  end

  def validate_agent_emails
    invalid_emails = to_emails - Account.current.agents_details_from_cache.map { |x| x.email }
    unless invalid_emails.empty?
      errors[:notify_emails] << :invalid_agent_emails
      (self.error_options ||= {}).merge!(notify_emails: { invalid_emails: "#{invalid_emails.join(', ')}" })
    end
  end

  def validate_from_email
  	email_config = Account.current.email_configs.where(reply_email: from_email).first
    if email_config
      self.email_config_id = email_config.id
      self.email_config = email_config
    else
      errors[:from_email] << :"can't be blank"
    end
  end

  def validate_agent_id
    user = Account.current.agents_details_from_cache.find { |x| x.id == user_id }
    errors[:agent_id] << :"is invalid" unless user
  end

  def validate_tracker_id
    errors[:id] << :"is invalid" unless notable.tracker_ticket?
  end

  def validate_cloud_file_ids
    invalid_file_ids = @cloud_file_ids - @cloud_file_attachments.map(&:id)
    if invalid_file_ids.any?
      errors[:cloud_file_ids] << :invalid_list
      (self.error_options ||= {}).merge!({ cloud_file_ids: { list: "#{invalid_file_ids.join(', ')}" } })
    end
  end

  def validate_send_survey
    unless Account.current.new_survey_enabled? && Account.current.active_custom_survey_from_cache.try(:can_send?, notable, Survey::SPECIFIC_EMAIL_RESPONSE)
      errors[:send_survey] << :should_be_blank
    end
    self.send_survey = self.send_survey ? "1" : "0"
  end

  def validate_application_id
    application_ids = cloud_files.map(&:application_id)
    applications = Integrations::Application.where('id IN (?)', application_ids)
    invalid_ids = application_ids - applications.map(&:id)
    if invalid_ids.any?
      errors[:application_id] << :invalid_list
      (self.error_options ||= {}).merge!({ application_id: { list: "#{invalid_ids.join(', ')}" } })
    end
  end

  alias :validate_unseen_replies_for_public_notes :validate_unseen_replies
  # We need an alias method here, because a custom validator method can be used only for one action

  private

    # skip parent and shared attachments
    def skip_existing_attachments(options)
      options[:attachment_ids] - (options[:parent_attachments] || []).map(&:id) - (options[:shared_attachments] || []).map(&:id)
    end

    def retrieve_cloud_files
      @cloud_file_attachments = notable.cloud_files.where(id: @cloud_file_ids)
    end

    def public_note?
      !self.private.nil? and !self.private
    end
end
