module MailboxValidator
  include Email::Mailbox::Constants
  include Email::Mailbox::Oauth2Helper

  class IdleNotSupportedError < StandardError
  end

  class RefreshAccessTokenError < StandardError
  end

  MAILBOX_ATTRIBUTES = %w[server_name port use_ssl delete_from_server authentication user_name password].freeze

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
      Rails.logger.info ">>>mailbox imap #{mailbox.inspect}"
      args = mailbox.attributes.slice(*MAILBOX_ATTRIBUTES).with_indifferent_access
      verified = false
      msg = ""
      begin
        imap = Net::IMAP.new(args[:server_name], args[:port].to_s, args[:use_ssl])

        if 'plain'.casecmp(args[:authentication]).zero?
          imap.login(args[:user_name], args[:password])
        elsif Email::Mailbox::Constants::OAUTH.casecmp(args[:authentication]).zero?
          if mailbox.error_type.nil? || mailbox.error_type.zero?
            refresh_access_token(mailbox) if access_token_expired?(mailbox)
            raise RefreshAccessTokenError, 'Error refreshing access token' unless mailbox.error_type.nil? || mailbox.error_type.zero?
          end
          imap.authenticate(args[:authentication], args[:user_name], mailbox.access_token)
        else
          imap.authenticate(args[:authentication], args[:user_name], args[:password])
        end

        raise IdleNotSupportedError, "Mailbox server does not support IDLE" unless imap.capability.include?("IDLE")

        imap.logout()
        verified = true
      rescue RefreshAccessTokenError => error
        msg = :refresh_access_token_error
        Rails.logger.debug "error while verifying the imap details : #{error}"
      rescue IdleNotSupportedError => error
        msg = :imap_idle_not_supported
        Rails.logger.debug "error while verifying the imap details : #{error}"
      rescue SocketError => error
        msg = :imap_connection_error
        Rails.logger.debug "error while verifying the imap details : #{error}"
      rescue Exception => error
        msg = :imap_error
        Rails.logger.debug "error while verifying the imap details : #{error}"      
      end
      { success: verified, msg: msg }    
    end

    def verify_smtp_mailbox(mailbox)
      Rails.logger.info ">>>mailbox smtp #{mailbox.inspect}"
      args = mailbox.attributes.slice(*MAILBOX_ATTRIBUTES).with_indifferent_access
      verified = false
      msg = ''
      options = ''
      begin
        smtp = Net::SMTP.new(args[:server_name], args[:port].to_s)
        if args[:port].to_i == 465
          smtp.enable_ssl
        elsif args[:port].to_i == 587
          smtp.enable_starttls
        end
        password = args[:password]
        if 'xoauth2'.casecmp(args[:authentication]).zero?
          if mailbox.error_type.nil? || mailbox.error_type.zero?
            refresh_access_token(mailbox) if access_token_expired?(mailbox)
            raise RefreshAccessTokenError, 'Error refreshing access token' unless mailbox.error_type.nil? || mailbox.error_type.zero?
          end
          password = mailbox.access_token
        end
        smtp.start(args[:server_name], args[:user_name], password, args[:authentication]) do |smtp|
        end
        verified = true
      rescue RefreshAccessTokenError => error
        msg = :refresh_access_token_error
        Rails.logger.debug "error while verifying the imap details : #{error}"
      rescue Timeout::Error => error
        msg = :smtp_timed_out
        Rails.logger.debug "error while verifying the smtp details : #{error}"
      rescue SocketError => error
        msg = :smtp_socket_error
        Rails.logger.debug "error while verifying the smtp details : #{error}"
      rescue Net::SMTPAuthenticationError => error
        msg = :smtp_invalid_credentials
        Rails.logger.debug "error while verifying the smtp details : #{error}"
      rescue Exception => error
        msg = :smtp_error
        options = { :error => error.message }
        Rails.logger.debug "error while verifying the smtp details : #{error}"
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
end
