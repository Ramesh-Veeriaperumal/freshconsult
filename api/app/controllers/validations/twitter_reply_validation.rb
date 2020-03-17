class TwitterReplyValidation < ApiValidation

  include Twitter::TwitterText::Validation

  include Social::Util
  include Social::Twitter::Util

  attr_accessor :body, :tweet_type, :twitter_handle_id, :agent_id, :attachment_ids

  validates :tweet_type, data_type: { rules: String, required: true }, custom_inclusion: { in: ApiConstants::TWITTER_REPLY_TYPES }
  validates :body, data_type: { rules: String, required: true }
  validate :valid_body_length?
  validates :twitter_handle_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param, required: true }
  validates :agent_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

  validate :twitter_ticket?
  validate :valid_attachments?, if: -> { @attachment_ids.present? }

  def initialize(request_params, item = nil, allow_string_param = false)
    @item = item
    super
  end

  def twitter_ticket?
    errors[:ticket_id] << :not_a_twitter_ticket unless @item.twitter?
  end

  def valid_attachments?
    attachment_config = ApiConstants::TWITTER_ATTACHMENT_CONFIG[@tweet_type.to_sym]
    attachments = Helpdesk::Attachment.find_all_by_id(@attachment_ids) if attachment_config.present?

    if attachments.present? && attachments.length == @attachment_ids.length
      attachment_types = []
      attachment_sizes = []

      attachments.each do |attachment|
        content_type = attachment.content_content_type
        return unless valid_attachment_type?(content_type)
        attachment_types << ApiConstants::TWITTER_ALLOWED_ATTACHMENT_TYPES[content_type]
        attachment_sizes << attachment.content_file_size
      end
      return unless unique_attachments?(attachment_types.uniq) &&
                    valid_attachment_limits?(attachment_types, attachment_config) &&
                    valid_attachment_sizes?(attachment_sizes, attachment_types, attachment_config)
    else
      errors[:attachment_ids] << :twitter_attachment_invalid
    end
  end

  def valid_attachment_type?(attachment_format)
    valid = ApiConstants::TWITTER_ALLOWED_ATTACHMENT_TYPES.keys.include?(attachment_format)
    errors[:attachment_ids] << :twitter_attachment_file_invalid unless valid
    valid
  end

  def unique_attachments?(unique_attachment_types)
    valid = unique_attachment_types.length == 1
    errors[:attachment_ids] << :twitter_attachment_file_unique_type unless valid
    valid
  end

  def valid_attachment_limits?(attachment_types, attachment_config)
    attachment_type = attachment_types[0]
    limit = attachment_config[attachment_type.to_sym]['limit'.to_sym]
    valid = attachment_types.length <= limit
    errors[:attachment_ids] << :twitter_attachment_file_limit unless valid
    self.error_options.merge!(attachment_ids: { maxLimit: limit, fileType: attachment_type })
    valid
  end

  def valid_attachment_sizes?(attachment_sizes, attachment_types, attachment_config)
    attachment_size = ((attachment_sizes.max.to_f / 1024) / 1024)
    attachment_type = attachment_types[0]
    size_limit = attachment_config[attachment_type.to_sym]['size'.to_sym]
    valid = attachment_size <= size_limit
    errors[:attachment_ids] << :twitter_attachment_single_file_size unless valid
    self.error_options.merge!(attachment_ids: { fileType: attachment_type.capitalize, maxSize: size_limit })
    valid
  end
  
  private

    def valid_body_length?
      return false if @body.blank?
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
end