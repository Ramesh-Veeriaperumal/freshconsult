class HelpWidget::UploadConfig < BaseWorker

  sidekiq_options queue: :widget_upload_config,
                  retry: 1,
                  failures: :exhausted
  
  S3_UPLOAD_OPTIONS = { 
    :acl => 'public-read',
    :content_type => 'application/json'
  }

  def perform args
    @args = args.symbolize_keys
    if widget && !destroy?
      upload_json
    else
      delete_json
    end
  end

  private

    def widget
      @widget ||= Account.current.help_widgets.active.find_by_id(@args[:widget_id].to_i)
    end

    def destroy?
      @args[:_destroy]
    end

    def upload_json
      AwsWrapper::S3.put(S3_CONFIG[:help_widget_bucket], widget_path, widget_json, S3_UPLOAD_OPTIONS.merge(server_side_encryption: 'AES256'))
      create_zero_byte_file
    rescue => e
      log_error("Upload Error", e)
    end

    # dummy file for redirection
    def create_zero_byte_file
      upload_options = S3_UPLOAD_OPTIONS.clone
      upload_options.merge!({:website_redirect_location => HelpWidget::BOOTSTRAP_REDIRECTION_PATH})
      AwsWrapper::S3.put(S3_CONFIG[:help_widget_bucket], zero_byte_file_path, '', upload_options.merge(server_side_encryption: 'AES256'))
    end

    def delete_json
      AwsWrapper::S3.delete(S3_CONFIG[:help_widget_bucket], widget_path)
      AwsWrapper::S3.delete(S3_CONFIG[:help_widget_bucket], zero_byte_file_path)
    end

    def widget_json
      JSON.pretty_generate(widget.as_api_response(:s3_format))
    end

    def widget_path
      @widget_path ||= HelpWidget::FILE_PATH % { :widget_id => @args[:widget_id] }
    end

    def zero_byte_file_path
      @zero_byte_file_path ||= HelpWidget::ZERO_BYTE_FILE_PATH % { :widget_id => @args[:widget_id] }
    end

    def log_error statement, e
      Rails.logger.error "#{statement} - #{Account.current.id} - #{@args.inspect} - #{e.message}"
      return if Rails.env.development? || Rails.env.test?

      params = @args.merge(
        account_id: Account.current.id,
        domain: Account.current.full_domain
      )
      FreshdeskErrorsMailer.error_email(nil, params, e,
                                        subject: "#{Rails.env} - #{statement}",
                                        recipients: ['the-a-team@freshworks.com'])
    end
end
