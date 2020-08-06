Paperclip::Storage::S3.module_eval do
  PUBLIC_DESCRIPTIONS = %w(logo fav_icon public content_id) 
  def flush_writes #:nodoc:
    @queued_for_write.each do |style, file|
      begin
        log("Freshdesk saving #{path(style)}")
        acl = s3_helpkit_permissions
        acl = acl.call(self, style) if acl.respond_to?(:call)
        write_options = {
          :content_type => file.content_type.to_s.strip,
          :acl => acl
        }
        write_options[:metadata] = @s3_metadata unless @s3_metadata.empty?
        unless @s3_server_side_encryption.blank?
          write_options[:server_side_encryption] = @s3_server_side_encryption
        end
        write_options.merge!(@s3_headers)
        s3_object(style).write(file, write_options)
      rescue Aws::S3::Errors::NoSuchBucket
        create_bucket
        retry
      end
    end
    after_flush_writes # allows attachment to clean up temp files

    @queued_for_write = {}
  end

  def s3_helpkit_permissions
    (self.instance.description and PUBLIC_DESCRIPTIONS.include?(self.instance.description))? "public-read" : "private"
  end
end

