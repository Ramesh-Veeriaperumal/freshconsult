class DeletedBodyObserver < ActiveRecord::Observer
  MODEL_COLUMNS_HASH = {
    Helpdesk::Ticket => :description_html,
    Helpdesk::Note => :body_html,
    Post => :body_html
  }

  observe *MODEL_COLUMNS_HASH.keys

  def after_commit(deleted_object)
    if deleted_object.safe_send(:transaction_include_action?, :destroy)
      attribute = MODEL_COLUMNS_HASH[deleted_object.class]
      self.class.write_to_s3(deleted_object.safe_send(attribute), deleted_object.class.name, deleted_object.id)
      InlineImageShredder.perform_async(model_name: deleted_object.class.name, model_id: deleted_object.id)
    end
    true
  end

  private
    def self.write_to_s3(content, model_name, model_id)
      path = cleanup_file_path(Account.current.id, model_name, model_id)
      AwsWrapper::S3.put(S3_CONFIG[:bucket], path, content, server_side_encryption: 'AES256')
    end

    def self.cleanup_file_path(account_id, model_name, model_id)
      "attachment_cleanup/#{account_id}/#{model_name}/#{model_id}"
    end
end
 