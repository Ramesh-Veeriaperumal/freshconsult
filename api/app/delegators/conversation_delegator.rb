class ConversationDelegator < ConversationBaseDelegator
  include Twitter::TwitterText::Validation
  include Redis::OthersRedis
  include Redis::RedisKeys

  attr_accessor :email_config_id, :email_config, :cloud_file_attachments, :parent_note_id, :parent_note, :fb_page, :ticket_source, :msg_type, :twitter_handle_id, :tweet_type, :body, :twitter_handle, :reply_ticket_id

  validate :validate_agent_emails, if: -> { note? && !reply_to_forward? && to_emails.present? && attr_changed?('to_emails', schema_less_note) }

  validate :validate_from_email, if: -> { (email_conversation? || (schema_less_note.present? && reply_to_forward?)) && from_email.present? && attr_changed?('from_email', schema_less_note) }

  validate :validate_agent_id, if: -> { (fwd_email? && user_id.present? && attr_changed?('user_id')) || (social_ticket? && user_id.present?) }

  validate :validate_reply_ticket_id, if: -> { reply_ticket_id.present? }

  validate :validate_tracker_id, if: -> { broadcast_note? }

  validate :validate_cloud_file_ids, if: -> { @cloud_file_ids }

  validate :validate_inline_attachment_ids, if: -> { @inline_attachment_ids }

  validate :validate_application_id, if: -> { cloud_files.present? }

  validate :validate_send_survey, unless: -> { send_survey.nil? }

  validate :validate_survey_monkey, unless: -> { include_surveymonkey_link.nil? }

  validate :validate_unseen_replies, on: :reply, if: :traffic_cop_required?
  validate :validate_unseen_replies_for_notes, on: :create, if: :traffic_cop_required?

  validate :ticket_summary_presence


  # Facebook reply delegation check
  validate :validate_parent_note_id, if: -> { facebook_ticket? && parent_note_id.present? && reply? }
  validate :validate_page_state, if: -> { facebook_ticket? && reply? }
  validate :validate_attachments, if: -> { facebook_ticket? && @attachments.present? && (msg_type == Facebook::Constants::FB_MSG_TYPES[1]) && reply? }

  # Twitter reply delegation check
  validate :valid_body_length_twitter, :validate_twitter_handle, :check_twitter_app_state, :validate_twitter_attachments, if: -> { twitter_ticket? }, on: :reply

  def initialize(record, options = {})
    super(record, options)
    @cloud_file_ids = options[:cloud_file_ids]
    @inline_attachment_ids = options[:inline_attachment_ids]
    retrieve_cloud_files if @cloud_file_ids
    @conversation = record
    @notable = options[:notable]
    @reply_ticket_id = options[:reply_ticket_id]
    initialize_fb_variables(options) if Account.current.launched?(:facebook_public_api)
    initialize_twitter_variables(options) if Account.current.launched?(:twitter_public_api)
  end

  def initialize_fb_variables(options = {})
    @parent_note_id = options[:parent_note_id]
    @fb_page = options[:fb_page]
    @msg_type = options[:msg_type]
    @ticket_source = options[:ticket_source]
    @attachments = options[:attachments]
  end

  def initialize_twitter_variables(options = {})
    @body = options[:body]
    @tweet_type = options[:tweet_type]
    @twitter_handle_id = options[:twitter_handle_id]
    @ticket_source = options[:ticket_source]
    @attachments = options[:attachments]
  end

  def reply?
    validation_context == :reply
  end

  def facebook_ticket?
    Account.current.launched?(:facebook_public_api) && ticket_source.present? && (ticket_source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook])
  end

  def twitter_ticket?
    Account.current.launched?(:twitter_public_api) && ticket_source.present? && (ticket_source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter])
  end

  def social_ticket?
    ticket_source.present? && (facebook_ticket? || twitter_ticket?)
  end

  def validate_reply_ticket_id
    invalid_ticket_reply_error(:reply_ticket_id) if reply_ticket_id.to_i != notable.display_id
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

  def valid_body_length_twitter
    return false if @body.blank? || errors.present?

    parsed_result = parse_tweet(@body)
    total_length = parsed_result[:weighted_length]
    max_length = (@tweet_type || '').to_sym == :dm ? ApiConstants::TWITTER_DM_MAX_LENGTH : ApiConstants::TWEET_MAX_LENGTH
    if max_length < total_length
      errors[:body] << :too_long
      self.error_options.merge!(body: { current_count: total_length, element_type: 'characters', max_count: max_length })
      return false
    end
    true
  end

  def validate_twitter_handle
    @twitter_handle = Account.current.twitter_handles.where(twitter_user_id: @twitter_handle_id).first
    return errors[:twitter_handle_id] << :"is invalid" unless twitter_handle

    errors[:twitter_handle_id] << :"requires re-authorization" if twitter_handle.reauth_required?
  end

  def check_twitter_app_state
    errors[:twitter] << :twitter_write_access_blocked if redis_key_exists?(TWITTER_APP_BLOCKED)
  end

  def validate_twitter_attachments
    if @attachments.present?
      attachment_config = ApiConstants::TWITTER_ATTACHMENT_CONFIG[@tweet_type.to_sym]
      attachment_types = []
      attachment_sizes = []

      @attachments.each do |attachment|
        content_type = attachment[:resource].content_type
        return unless valid_twitter_attachment_type?(content_type)

        attachment_types << ApiConstants::TWITTER_ALLOWED_ATTACHMENT_TYPES[content_type]
        attachment_sizes << attachment[:resource].size
      end
      return unless unique_twitter_attachments?(attachment_types.uniq) &&
                    valid_twitter_attachment_limits?(attachment_types, attachment_config) &&
                    valid_twitter_attachment_sizes?(attachment_sizes, attachment_types, attachment_config)
    end
  end

  def valid_twitter_attachment_type?(attachment_format)
    valid = ApiConstants::TWITTER_ALLOWED_ATTACHMENT_TYPES.key?(attachment_format)
    errors[:attachments] << :twitter_attachment_file_invalid unless valid
    valid
  end

  def unique_twitter_attachments?(unique_attachment_types)
    valid = unique_attachment_types.length == 1
    errors[:attachments] << :twitter_attachment_file_unique_type unless valid
    valid
  end

  def valid_twitter_attachment_limits?(attachment_types, attachment_config)
    attachment_type = attachment_types[0]
    limit = attachment_config[attachment_type.to_sym]['limit'.to_sym]
    valid = attachment_types.length <= limit
    errors[:attachments] << :twitter_attachment_file_limit unless valid
    self.error_options.merge!(attachments: { maxLimit: limit, fileType: attachment_type })
    valid
  end

  def valid_twitter_attachment_sizes?(attachment_sizes, attachment_types, attachment_config)
    attachment_size = ((attachment_sizes.max.to_f / 1024) / 1024)
    attachment_type = attachment_types[0]
    size_limit = attachment_config[attachment_type.to_sym]['size'.to_sym]
    valid = attachment_size <= size_limit
    errors[:attachments] << :twitter_attachment_single_file_size unless valid
    self.error_options.merge!(attachments: { fileType: attachment_type.capitalize, maxSize: size_limit })
    valid
  end

  def validate_agent_emails
    invalid_emails = to_emails.map(&:downcase) - Account.current.agents_details_from_cache.map(&:email)
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

  alias validate_unseen_replies_for_notes validate_unseen_replies
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

    def retrieve_cloud_files
      @cloud_file_attachments = notable.cloud_files.where(id: @cloud_file_ids)
    end

    def public_note?
      !self.private.nil? && !self.private
    end

    def invalid_ticket_reply_error(field)
      options_hash = {
        account_id: Account.current.id,
        ticket_id: notable.display_id
      }
      NewRelic::Agent.notice_error('Reply crossover error', options_hash)
      Rails.logger.info "Reply crossover error : #{Account.current.id}"
      errors[field] << :invalid_ticket_reply
    end
end
