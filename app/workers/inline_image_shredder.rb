class InlineImageShredder < BaseWorker
  include InlineImagesUtil

  sidekiq_options :queue => :inline_image_shredder, :retry => 0, :failures => :exhausted

  TYPES_TO_BE_DELETED = ['Tickets Image Upload', 'Forums Image Upload', 'Ticket::Inline', 'Note::Inline'].freeze

  # For attachment with below types, we are checking whether that attachment belongs to the respective model.
  MODEL_INLINE_TYPES = ['Ticket::Inline', 'Note::Inline'].freeze

  def perform(args)
    args.symbolize_keys!
    path = DeletedBodyObserver.cleanup_file_path(Account.current.id, args[:model_name], args[:model_id])
    return unless AwsWrapper::S3.exists?(S3_CONFIG[:bucket], path)

    content = AwsWrapper::S3.read(S3_CONFIG[:bucket], path)
    attachment_ids = get_attachment_ids(content)
    Account.current.attachments.where(id: attachment_ids).find_each(batch_size: 300) do |attachment|
      attachment.destroy if should_delete?(attachment.id, attachment.attachable_type, attachment.attachable_id, args[:model_id])
    end
    AwsWrapper::S3.delete(S3_CONFIG[:bucket], path)
  rescue Aws::S3::Errors::NoSuchKey
    Rails.logger.error "Body Content not found in s3 :: #{Account.current.id} :: #{args.inspect}" 
  end

  private

    def should_delete?(attachment_id, attachment_type, attachable_id, model_id)
      return false unless TYPES_TO_BE_DELETED.include?(attachment_type)
      return false if attachment_type == 'Tickets Image Upload' && Account.current.canned_responses_inline_images_from_cache.include?(attachment_id)
      return false if MODEL_INLINE_TYPES.include?(attachment_type) && model_id != attachable_id

      true
    end
end
