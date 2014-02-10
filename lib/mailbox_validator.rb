module MailboxValidator

  class IdleNotSupportedError < StandardError
  end
  
  def validate_mailbox_details
    verify_result = verify_mailbox_details
    render :json => {:success => verify_result[:success], :msg => verify_result[:msg]}.to_json
  end

  private

    def verify_mailbox_details
      imap_verify = verify_imap_details?
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
      args = params[:email_config][:mailbox_attributes]
      verified = false
      msg = ""
      begin
        imap = Net::IMAP.new(args[:imap_server_name], args[:imap_port], args[:imap_use_ssl].to_bool)

        raise IdleNotSupportedError, "Mailbox server does not support IDLE" unless imap.capability.include?("IDLE")

        if "PLAIN".casecmp(args[:imap_authentication]) == 0
          imap.login(args[:imap_user_name], args[:imap_password])
        else
          imap.authenticate(args[:imap_authentication], args[:imap_user_name], args[:imap_password]) 
        end
        imap.logout()
        #msg = I18n.t('mailbox.authetication_success')
        verified = true
      rescue IdleNotSupportedError => error
        msg = I18n.t('mailbox.idle_not_supported')
        RAILS_DEFAULT_LOGGER.debug "error while verifying the imap details : #{error} #{params.inspect}"
      rescue SocketError => error
        msg = I18n.t('mailbox.imap_connection_error')
        RAILS_DEFAULT_LOGGER.debug "error while verifying the imap details : #{error} #{params.inspect}"
      rescue Exception => error
        msg = I18n.t('mailbox.imap_error')
        RAILS_DEFAULT_LOGGER.debug "error while verifying the imap details : #{error} #{params.inspect}"      
      end
      { :success => verified, :msg => msg }
    end

    def verify_smtp_details?
      args = params[:email_config][:mailbox_attributes]
      verified = false
      msg = ""
      begin
        Net::SMTP.start(args[:smtp_server_name], args[:smtp_port],args[:smtp_server_name], args[:smtp_user_name], args[:smtp_password], args[:smtp_authentication]) do |smtp|
        end
        #flash[:notice] = I18n.t('mailbox.authetication_success')
        verified = true
      rescue Timeout::Error => error
        msg = I18n.t('mailbox.smtp_timed_out')
        RAILS_DEFAULT_LOGGER.debug "error while verifying the smtp details : #{error} #{params.inspect}"
      rescue SocketError => error
        msg = I18n.t('mailbox.smtp_socket_error')
        RAILS_DEFAULT_LOGGER.debug "error while verifying the smtp details : #{error} #{params.inspect}"
      rescue Net::SMTPAuthenticationError => error
        msg = I18n.t('mailbox.invalid_credentials')
        RAILS_DEFAULT_LOGGER.debug "error while verifying the smtp details : #{error} #{params.inspect}"
      rescue Exception => error
        msg = I18n.t('mailbox.smtp_error', :error => error.message)
        RAILS_DEFAULT_LOGGER.debug "error while verifying the smtp details : #{error} #{params.inspect}"
      end
      { :success => verified, :msg => msg }
    end
end