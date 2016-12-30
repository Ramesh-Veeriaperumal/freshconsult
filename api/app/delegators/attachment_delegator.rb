class AttachmentDelegator < BaseDelegator
  validate :validate_user_id, if: -> { self[:attachable_id] && attachable_type == AttachmentConstants::STANDALONE_ATTACHMENT_TYPE }
  validate :validate_inline_image

  def initialize(record, options = {})
    super(record)
    @user = options[:user]
    @api_user = options[:api_user]
  end

  def validate_user_id
    errors[:user_id] << :"is invalid" unless @user || attachable_id == @api_user.id
  end

  def validate_inline_image
    return unless self.inline_image?
    errors[:content] << :incorrect_image_dimensions unless self.image? && self.valid_image?
  end
end
