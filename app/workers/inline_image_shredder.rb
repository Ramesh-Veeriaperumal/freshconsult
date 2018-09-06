class InlineImageShredder < BaseWorker
  include InlineImagesUtil

  sidekiq_options :queue => :inline_image_shredder, :retry => 0, :backtrace => true, :failures => :exhausted

  TYPES_TO_BE_DELETED = ['Tickets Image Upload', 'Forums Image Upload', 'Ticket::Inline', 'Note::Inline']

  def perform(args)
    args.symbolize_keys!
    path = DeletedBodyObserver.cleanup_file_path(Account.current.id, args[:model_name], args[:model_id])
    return unless AwsWrapper::S3Object.exists?(path, S3_CONFIG[:bucket])
    content = AwsWrapper::S3Object.read(path, S3_CONFIG[:bucket])
    attachment_ids = get_attachment_ids(content)
    Account.current.attachments.where(id: attachment_ids).find_each(batch_size: 300) do |attachment|
      attachment.destroy if should_delete?(attachment.id, attachment.attachable_type)
    end
    AwsWrapper::S3Object.delete(path, S3_CONFIG[:bucket])
  rescue AWS::S3::Errors::NoSuchKey => e
    Rails.logger.error "Body Content not found in s3 :: #{Account.current.id} :: #{args.inspect}" 
  end

  private

    def should_delete?(attachment_id, attachment_type)
      return false unless TYPES_TO_BE_DELETED.include?(attachment_type)
      return false if attachment_type == 'Tickets Image Upload' && Account.current.canned_responses_inline_images_from_cache.include?(attachment_id)
      true
    end
end
