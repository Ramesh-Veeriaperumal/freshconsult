class ProductFeedbackWorker < BaseWorker
  sidekiq_options queue: :product_feedback, retry: 0,  failures: :exhausted

  def perform(payload)
    payload.symbolize_keys!
    if payload[:current_user_id].present?
      user = Account.current.users.where(id: payload[:current_user_id]).first
      user.make_current if user.present?
    end
    api_key = PRODUCT_FEEDBACK_CONFIG['api_key']
    feedback_url = URI.parse("#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['feedback_path']}")
    files_to_upload = get_attachments(payload[:attachment_ids]) if payload[:attachment_ids].present? && User.current.present?
    if @attachments.length != payload[:attachment_ids].length
      NewRelic::Agent.notice_error('Failed to retrieve all attachments', payload: payload, attachments: @attachments)
      Rails.logger.error("Failed to retrieve all attachments. Payload = #{payload.to_json}. Attachments = #{@attachments.to_json}")
    end
    format_payload(payload, files_to_upload)
    http_resp = create_feedback(feedback_url, payload, api_key)
    clean_local_files(files_to_upload) if files_to_upload.present?
    if ticket_creation_successful?(http_resp)
      # destroy attachment relation and clear data from S3 (of current account)
      @attachments.each(&:destroy) if @attachments.present?
    else
      NewRelic::Agent.notice_error('Feedback creation failed', payload: payload, http_response_body: http_resp.read_body)
      Rails.logger.error("Feedback creation failed. Payload = #{payload.to_json}. HTTP Response = #{http_resp.read_body}")
    end
  end

  private

    # successful if response is 201 and number of attachments created is the number of attachments passed
    def ticket_creation_successful?(http_resp)
      response = JSON.parse(http_resp.body).symbolize_keys
      (http_resp.code.to_i == 201) && (response[:attachments].length == @attachments.length)
    end

    # transfer content using multipart-post gem
    def create_feedback(url, payload, api_key)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = (url.scheme == 'https')
      http.start do
        req = Net::HTTP::Post::Multipart.new(url, payload)
        req.add_field('Authorization', "Basic #{Base64.encode64(api_key).strip}")
        http.request(req)
      end
    end

    # get attachment objects from DB and attachment data from AWS S3
    def get_attachments(attachment_ids)
      @attachments = Account.current.attachments.permissible_drafts(User.current).where(id: attachment_ids)
      files_to_upload = []
      @attachments.each do |attachment|
        file = UploadIO.new(create_new_file(attachment), attachment.content_content_type, attachment.content_file_name)
        file.write(AwsWrapper::S3Object.read(attachment.content.path, attachment.content.bucket_name))
        file.flush.seek(0, IO::SEEK_SET) # flush data to file and set RW pointer to beginning
        files_to_upload.push(file)
      end
      files_to_upload
    end

    # cleans files created on local
    def clean_local_files(upload_files)
      upload_files.each do |file|
        file.close unless file.closed?
        File.delete(file)
      end
    end

    # removes unwanted keys and add wanted keys
    def format_payload(payload, files_to_upload = nil)
      payload[:"attachments[]"] = files_to_upload if files_to_upload.present?
      payload.delete(:attachment_ids) if payload.key? :attachment_ids
      payload.delete(:ticket_reference) if payload.key? :ticket_reference
      if payload[:tags].present?
        payload[:"tags[]"] = payload[:tags]
        payload.delete(:tags)
      end
    end

    # creates a new file in local and returns the file pointer
    def create_new_file(attachment)
      attachment_filename = "tempFile-#{Account.current.id}-#{attachment.id}-#{Time.zone.now.strftime('%d_%m_%Y_%H_%M_%S')}"
      Tempfile.new(attachment_filename)
    end
end
