module Concerns::CustomerNote::Methods
  extend ActiveSupport::Concern

  included do
    def body
      note_body.try(:body)
    end

    # Developer use
    # def body_from_s3
    #   content = nil
    #   if s3_key
    #     content = Helpdesk::S3::CustomerNote::Body.get_from_s3(account_id, id, S3_CONFIG[s3_bucket])
    #     content = content[:body.to_s]
    #   end
    #   content
    # end

    def s3_url
      path = Helpdesk::S3::CustomerNote::Body.generate_file_path(account_id, id)
      AwsWrapper::S3.presigned_url(S3_CONFIG[s3_bucket], path, secure: true) # :response_content_type => "application/json"
    end

    def body_changed?
      note_body.try(:body_changed?)
    end

    def created_by_name
      Account.current.all_users.find_by_id(created_by).try(:name)
    end

    def last_updated_by_name
      Account.current.all_users.find_by_id(last_updated_by).try(:name)
    end

    def populate_s3_key
      self.s3_key = true
      self.save
    end

    private

      def klass_name
        self.class.name.demodulize.underscore.to_sym
      end

      def s3_bucket
        Concerns::CustomerNote::Constants::S3_BUCKET[klass_name]
      end
  end
end
