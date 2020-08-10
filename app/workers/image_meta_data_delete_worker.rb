class ImageMetaDataDeleteWorker < BaseWorker
  require 'open3'
  sidekiq_options :queue => :image_meta_data_delete, :retry => 0, :failures => :exhausted

  def perform(args)
    Rails.logger.info "ImageMetaDataDeleteWorker started. args : #{args.inspect}"
    args.symbolize_keys!
    s3_paths = args[:s3_paths]
    s3_bucket = args[:s3_bucket]
    write_options = { acl: args[:s3_permissions], server_side_encryption: 'AES256' }
    s3_paths.each do |s3_path|
      AwsWrapper::S3Functions.perform_operations_in_s3_attachment(s3_path, s3_bucket, 'image-attachments') do |local_file, path, bucket|
        _stdout, stderr, status = Open3.capture3("exiftool -all= -tagsFromFile @ -Orientation -overwrite_original #{local_file.path}")
        raise StandardError, "Error in exiftool, error : #{stderr}" if status.to_s[-1, 1] == '1'
        File.open(local_file.path) { |file| AwsWrapper::S3.put(bucket, path, file, write_options) }
      end
    end
  rescue StandardError => e
    Rails.logger.error "Exception in removing image meta-data \
      acc_id: #{Account.current.try(:id)}, args: #{args.inspect}, error message: #{e.message}, error: #{e.backtrace.join('\n')}"
    NewRelic::Agent.notice_error(e, description: "Exception in removing image meta-data \
      acc_id: #{Account.current.try(:id)}, args: #{args.inspect}")
    raise e
  end
end
