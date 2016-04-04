module MailboxValidator

  class IdleNotSupportedError < StandardError
  end
  
  def validate_mailbox_details
    verify_result = verify_mailbox_details
    render :json => {:success => verify_result[:success], :msg => verify_result[:msg]}.to_json
  end

  private

    def verify_mailbox_details
      unless params[:email_config][:imap_mailbox_attributes][:_destroy].to_bool
        imap_verify = verify_imap_details?
      else
        imap_verify = { :success => true }
      end
      smtp_verify = verify_smtp_details?
      verified = imap_verify[:success] && smtp_verify[:success]
      unless imap_verify[:success] || smtp_verify[:success]
        msg = [imap_verify[:msg], smtp_verify[:msg]].join("<br />")
      else
        msg = imap_verify[:success] ? smtp_verify[:msg] : imap_verify[:msg]
      end

      {:success => verified, :msg => msg}
    end
    
    def verify_imap_details?
      args = params[:email_config][:imap_mailbox_attributes]
      filtered_params = args.except(:password)
      verified = false
      msg = ""
      begin
        imap = Net::IMAP.new(args[:server_name], args[:port], args[:use_ssl].to_bool)

        raise IdleNotSupportedError, "Mailbox server does not support IDLE" unless imap.capability.include?("IDLE")

        if "PLAIN".casecmp(args[:authentication]) == 0
          imap.login(args[:user_name], args[:password])
        else
          imap.authenticate(args[:authentication], args[:user_name], args[:password]) 
        end
        imap.logout()
        #msg = I18n.t('mailbox.authetication_success')
        verified = true
      rescue IdleNotSupportedError => error
        msg = I18n.t('mailbox.idle_not_supported')
        Rails.logger.debug "error while verifying the imap details : #{error} #{filtered_params.inspect}"
      rescue SocketError => error
        msg = I18n.t('mailbox.imap_connection_error')
        Rails.logger.debug "error while verifying the imap details : #{error} #{filtered_params.inspect}"
      rescue Exception => error
        msg = I18n.t('mailbox.imap_error')
        Rails.logger.debug "error while verifying the imap details : #{error} #{filtered_params.inspect}"      
      end
      { :success => verified, :msg => msg }
    end

    def verify_smtp_details?
      args = params[:email_config][:smtp_mailbox_attributes]
      filtered_params = args.except(:password)
      verified = false
      msg = ""
      begin
        Net::SMTP.start(args[:server_name], args[:port],args[:server_name], args[:user_name], args[:password], args[:authentication]) do |smtp|
        end
        #flash[:notice] = I18n.t('mailbox.authetication_success')
        verified = true
      rescue Timeout::Error => error
        msg = I18n.t('mailbox.smtp_timed_out')
        Rails.logger.debug "error while verifying the smtp details : #{error} #{filtered_params.inspect}"
      rescue SocketError => error
        msg = I18n.t('mailbox.smtp_socket_error')
        Rails.logger.debug "error while verifying the smtp details : #{error} #{filtered_params.inspect}"
      rescue Net::SMTPAuthenticationError => error
        msg = I18n.t('mailbox.invalid_credentials')
        Rails.logger.debug "error while verifying the smtp details : #{error} #{filtered_params.inspect}"
      rescue Exception => error
        msg = I18n.t('mailbox.smtp_error', :error => error.message)
        Rails.logger.debug "error while verifying the smtp details : #{error} #{filtered_params.inspect}"
      end
      { :success => verified, :msg => msg }
    end
end