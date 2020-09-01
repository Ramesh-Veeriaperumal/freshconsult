module MailboxValidator
  include Email::Mailbox::Oauth2Helper
  class IdleNotSupportedError < StandardError
  end

  def validate_mailbox_details
    verify_result = verify_mailbox_details
    render json: { success: verify_result[:success], msg: verify_result[:msg] }.to_json
  end

  private

    MAIL_VALIDATION_TIMEOUT = 10

    def verify_mailbox_details
      imap_verify = if params[:email_config][:imap_mailbox_attributes][:_destroy].to_bool
                      { success: true }
                    else
                      verify_imap_details?
                    end
      smtp_verify = verify_smtp_details?
      verified    = imap_verify[:success] && smtp_verify[:success]
      msg         = if imap_verify[:success] || smtp_verify[:success]
                      imap_verify[:success] ? smtp_verify[:msg] : imap_verify[:msg]
                    else
                      [imap_verify[:msg], smtp_verify[:msg]].join('<br />')
                    end

      { success: verified, msg: msg }
    end

    def verify_imap_mailbox(mailbox)
      verified = false
      msg = ''
      begin
        imap = Net::IMAP.new(mailbox.server_name, mailbox.port.to_s, mailbox.use_ssl)

        if 'plain'.casecmp(mailbox.authentication).zero?
          imap.login(mailbox.user_name, mailbox.password)
        elsif 'xoauth2'.casecmp(mailbox.authentication).zero?
          refresh_access_token_for_mailbox(mailbox) if mailbox.new_record? || access_token_expired?(mailbox)
          imap.authenticate(mailbox.authentication, mailbox.user_name, mailbox.access_token)
        else
          imap.authenticate(mailbox.authentication, mailbox.user_name, mailbox.password)
        end

        raise IdleNotSupportedError, 'Mailbox server does not support IDLE' unless imap.capability.include?('IDLE')

        imap.logout
        verified = true
      rescue OAuth2::Error => e
        msg = :refresh_access_token_error
        Rails.logger.debug "error while verifying the imap details : #{e}"
      rescue IdleNotSupportedError => e
        msg = :imap_idle_not_supported
        Rails.logger.debug "error while verifying the imap details : #{e}"
      rescue SocketError => e
        msg = :imap_connection_error
        Rails.logger.debug "error while verifying the imap details : #{e}"
      rescue StandardError => e
        msg = :imap_error
        Rails.logger.debug "error while verifying the imap details : #{e}"
      end
      { success: verified, msg: msg }
    end

    def verify_smtp_mailbox(mailbox)
      verified = false
      msg = ''
      options = ''
      begin
        smtp = Net::SMTP.new(mailbox.server_name, mailbox.port.to_s)
        if mailbox.port.to_i == 465
          smtp.enable_ssl
        elsif mailbox.port.to_i == 587
          smtp.enable_starttls
        end
        password = mailbox.password
        if 'xoauth2'.casecmp(mailbox.authentication).zero?
          refresh_access_token_for_mailbox(mailbox) if mailbox.new_record? || access_token_expired?(mailbox)
          password = mailbox.access_token
        end
        smtp.start(mailbox.server_name, mailbox.user_name, password, mailbox.authentication) do |smtp|
        end
        verified = true
      rescue OAuth2::Error => e
        msg = :refresh_access_token_error
        Rails.logger.debug "error while verifying the imap details : #{e}"
      rescue Timeout::Error => e
        msg = :smtp_timed_out
        Rails.logger.debug "error while verifying the smtp details : #{e}"
      rescue SocketError => e
        msg = :smtp_socket_error
        Rails.logger.debug "error while verifying the smtp details : #{e}"
      rescue Net::SMTPAuthenticationError => e
        msg = :smtp_invalid_credentials
        Rails.logger.debug "error while verifying the smtp details : #{e}"
      rescue StandardError => e
        msg = :smtp_error
        options = { error: e.message }
        Rails.logger.debug "error while verifying the smtp details : #{e}"
      end
      { success: verified, msg: msg, options: options }
    end

    def verify_imap_details?
      args            = params[:email_config][:imap_mailbox_attributes]
      filtered_params = args.except(:password)
      verified        = false
      msg             = ''
      imap            = nil
      begin
        options        = {}
        options[:port] = args[:port]
        options[:ssl]  = { verify_mode: Net::IMAP::VERIFY_PEER } if args[:use_ssl].to_bool

        # We can be blocked/stuck in two scenarios
        #
        # 1. During imap connection phase
        #
        #   we will wrap it around in a
        #    timeout block!
        #
        # 2. During login/authenticate phase
        #
        #    To handle this, there is no read_timeout option. So we will wrap it
        #    around in a timeout block!
        #
        #    Note: this can happen not just when imap server is not responding,
        #    but can happen when it responds with wrong data, ruby imap
        #    implementation, will keep looping until it gets expected response,
        #    ignoring unknown tags (which means, forever)
        #

        # imap connection
        Timeout.timeout(MAIL_VALIDATION_TIMEOUT, Net::OpenTimeout) do
          imap = Net::IMAP.new(args[:server_name], options)
          if 'PLAIN'.casecmp(args[:authentication]).zero?
            imap.login(args[:user_name], args[:password])
          else
            imap.authenticate(args[:authentication], args[:user_name], args[:password])
          end
          # imap login
          raise IdleNotSupportedError, 'Mailbox server does not support IDLE' unless imap.capability.include?('IDLE')

          imap.logout
          # msg = I18n.t('mailbox.authetication_success')
        end
        verified = true
      rescue IdleNotSupportedError => error
        msg = I18n.t('mailbox.idle_not_supported')
        Rails.logger.error "error while verifying the imap details : #{error} #{filtered_params.inspect}"
      rescue SocketError, Net::OpenTimeout, Net::ReadTimeout => error
        msg = I18n.t('mailbox.imap_connection_error')
        Rails.logger.error "error while verifying the imap details : #{error.inspect} #{filtered_params.inspect}"
      rescue StandardError => error
        msg = I18n.t('mailbox.imap_error')
        Rails.logger.error "error while verifying the imap details : #{error} #{filtered_params.inspect}"
      ensure
        # Safe to ignore disconnect errors
        begin
          Timeout.timeout(MAIL_VALIDATION_TIMEOUT, Net::OpenTimeout) { imap.disconnect } if imap && !imap.disconnected?
        rescue StandardError => e
          Rails.logger.error("IMAP disconnect error: #{e.message} #{e.inspect}")
        end
      end

      { success: verified, msg: msg }
    end

    def verify_smtp_details?
      args            = params[:email_config][:smtp_mailbox_attributes]
      filtered_params = args.except(:password)
      verified        = false
      msg             = ''
      begin
        Timeout.timeout(MAIL_VALIDATION_TIMEOUT, Net::OpenTimeout) do
          smtp = Net::SMTP.new(args[:server_name], args[:port])
          if args[:port].to_i == 465
            smtp.enable_ssl
          elsif args[:port].to_i == 587
            smtp.enable_starttls
          end
          smtp.start(args[:server_name], args[:user_name], args[:password], args[:authentication]) {}
        end
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
      rescue StandardError => error
        msg = I18n.t('mailbox.smtp_error', error: error.message)
        Rails.logger.debug "error while verifying the smtp details : #{error} #{filtered_params.inspect}"
      end
      { success: verified, msg: msg }
    end

    def refresh_access_token_for_mailbox(mailbox)
      access_token_response = HashWithIndifferentAccess.new(
        get_oauth2_access_token(
          Email::Mailbox::Constants::APP_NAME_BY_SERVER_KEY[server_key(mailbox)],
          mailbox.refresh_token,
          Email::Mailbox::Constants::PROVIDER_NAME_BY_SERVER_KEY[server_key(mailbox)]
        )
      )
      mailbox.access_token = access_token_response[:access_token].token
    end
end
