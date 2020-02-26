class ConversationDelegator < ConversationBaseDelegator
  attr_accessor :email_config_id, :email_config, :cloud_file_attachments, :parent_note_id, :parent_note, :fb_page, :ticket_source, :msg_type

  validate :validate_agent_emails, if: -> { note? && !reply_to_forward? && to_emails.present? && attr_changed?('to_emails', schema_less_note) }

  validate :validate_from_email, if: -> { !social_ticket? && (email_conversation? || reply_to_forward?) && from_email.present? && attr_changed?('from_email', schema_less_note) }

  validate :validate_agent_id, if: -> { (fwd_email? && user_id.present? && attr_changed?('user_id')) || (facebook_ticket? && user_id.present?) }

  validate :validate_tracker_id, if: -> { broadcast_note? }

  validate :validate_cloud_file_ids, if: -> { @cloud_file_ids }

  validate :validate_inline_attachment_ids, if: -> { @inline_attachment_ids }

  validate :validate_application_id, if: -> { cloud_files.present? }

  validate :validate_send_survey, unless: -> { send_survey.nil? }

  validate :validate_survey_monkey, unless: -> { include_surveymonkey_link.nil? }

  validate :validate_unseen_replies, on: :reply, if: :traffic_cop_required?
  validate :validate_unseen_replies_for_public_notes, on: :create, if: -> { public_note? && traffic_cop_required? }

  validate :ticket_summary_presence

  validate :validate_parent_note_id, if: -> { facebook_ticket? && parent_note_id.present? }

  validate :validate_page_state, if: -> { facebook_ticket? }

  validate :validate_attachments, if: -> { facebook_ticket? && @attachments.present? && (msg_type == Facebook::Constants::FB_MSG_TYPES[1]) }

  def initialize(record, options = {})
    options[:attachment_ids] = skip_existing_attachments(options) if options[:attachment_ids]
    super(record, options)
    @cloud_file_ids = options[:cloud_file_ids]
    @inline_attachment_ids = options[:inline_attachment_ids]
    retrieve_cloud_files if @cloud_file_ids
    @conversation = record
    @notable = options[:notable]
    if Account.current.launched?(:fb_twitter_public_api)
      @parent_note_id = options[:parent_note_id]
      @fb_page = options[:fb_page]
      @msg_type = options[:msg_type]
      @ticket_source = options[:ticket_source]
      @attachments = options[:attachments]
    end
  end

  def facebook_ticket?
    Account.current.launched?(:fb_twitter_public_api) && ticket_source.present? && (ticket_source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook])
  end

  def social_ticket?
    Account.current.launched?(:fb_twitter_public_api) && ticket_source.present? && (ticket_source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook])
  end

  def validate_parent_note_id
    @parent_note = @notable.notes.find_by_id(parent_note_id)
    if @parent_note.present?
      errors[:parent_note_id] << :unable_to_post_reply unless @parent_note.fb_post.try(:post?) && @parent_note.fb_post.try(:can_comment?)
    else
      errors[:parent_note_id] << :"is invalid"
    end
  end

  def validate_page_state
    return errors[:fb_page_id] << :invalid_facebook_id unless fb_page

    if fb_page.reauth_required?
      errors[:fb_page_id] << :reauthorization_required
      (error_options[:fb_page_id] ||= {}).merge!(app_name: 'Facebook')
    end
  end

  def validate_attachments
    attachment = @attachments.first
    if attachment.present?
      attachment_format = attachment[:resource].content_type
      attachment_size = attachment_size_in_mb(attachment[:resource].size)
      unless ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:fileTypes].include?(attachment_format)
        errors[:attachments] << :attachment_format_invalid
        (self.error_options ||= {})[:attachments] = { attachment_formats: ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:fileTypes].join(', ').to_s }
      end
      if ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:size] < attachment_size
        errors[:attachments] << :file_size_limit_error
        (self.error_options ||= {})[:attachments] = { file_size: ApiConstants::FACEBOOK_ATTACHMENT_CONFIG[:post][:size] }
      end
    end
  end

  def validate_agent_emails
    invalid_emails = to_emails - Account.current.agents_details_from_cache.map(&:email)
    unless invalid_emails.empty?
      errors[:notify_emails] << :invalid_agent_emails
      (self.error_options ||= {}).merge!(notify_emails: { invalid_emails: invalid_emails.join(', ').to_s })
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
      (self.error_options ||= {}).merge!(cloud_file_ids: { list: invalid_file_ids.join(', ').to_s })
    end
  end

  def validate_inline_attachment_ids
    valid_ids = Account.current.attachments.where(id: @inline_attachment_ids, attachable_type: 'Tickets Image Upload').pluck(:id)
    valid_ids = valid_ids + @conversation.inline_attachment_ids unless @conversation.new_record? # Skip existing inline attachments while validating
    invalid_ids = @inline_attachment_ids - valid_ids
    if invalid_ids.present?
      errors[:inline_attachment_ids] << :invalid_inline_attachments_list
      (self.error_options ||= {}).merge!({ inline_attachment_ids: { invalid_ids: "#{invalid_ids.join(', ')}" } })
    end
  end

  def validate_send_survey
    unless Account.current.new_survey_enabled? && Account.current.active_custom_survey_from_cache.try(:can_send?, notable, Survey::SPECIFIC_EMAIL_RESPONSE)
      errors[:send_survey] << :should_be_blank
    end
    self.send_survey = self.send_survey ? '1' : '0'
  end

  def validate_survey_monkey
    survey_monkey = Account.current.installed_applications.with_name(Integrations::Constants::APP_NAMES[:surveymonkey]).first
    unless survey_monkey && can_send_survey_monkey?(survey_monkey)
      errors[:include_surveymonkey_link] << :should_be_blank
    end
  end

  def validate_application_id
    application_ids = cloud_files.map(&:application_id)
    applications = Integrations::Application.where('id IN (?)', application_ids)
    invalid_ids = application_ids - applications.map(&:id)
    if invalid_ids.any?
      errors[:application_id] << :invalid_list
      (self.error_options ||= {}).merge!(application_id: { list: invalid_ids.join(', ').to_s })
    end
  end

  def ticket_summary_presence
    errors[:id] << :"is invalid" if summary_note?
  end

  alias validate_unseen_replies_for_public_notes validate_unseen_replies
  # We need an alias method here, because a custom validator method can be used only for one action

  private

    def attachment_size_in_mb(size)
      ((size.to_f / 1024) / 1024)
    end

    # Replicating the old UI behaviour, surveymonkey link is active if requester is an agent,unlike in-app survey
    def can_send_survey_monkey?(survey_monkey)
      send_while = survey_monkey.configs[:inputs]['send_while']
      @conversation.user.agent? && [Survey::PLACE_HOLDER, Survey::SPECIFIC_EMAIL_RESPONSE].include?(send_while.to_i)
    end

    # skip parent and shared attachments
    def skip_existing_attachments(options)
      options[:attachment_ids] - (options[:parent_attachments] || []).map(&:id) - (options[:shared_attachments] || []).map(&:id)
    end

    def retrieve_cloud_files
      @cloud_file_attachments = notable.cloud_files.where(id: @cloud_file_ids)
    end

    def public_note?
      !self.private.nil? && !self.private
    end
end
