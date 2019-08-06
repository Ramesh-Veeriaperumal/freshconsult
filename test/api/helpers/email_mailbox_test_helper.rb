module EmailMailboxTestHelper
  def mailbox_pattern(expected_output, mailbox)
    response_pattern = {
      id: Fixnum,
      name: expected_output[:name] || mailbox.name,
      support_email: expected_output[:support_email] || mailbox.reply_email,
      group_id: expected_output[:group_id] || mailbox.group_id,
      default_reply_email: expected_output[:default_reply_email] || mailbox.primary_role,
      active: expected_output[:active] || mailbox.active,
      mailbox_type: expected_output[:mailbox_type] || ((mailbox.imap_mailbox.present? || mailbox.smtp_mailbox.present?) ? Email::Mailbox::Constants::CUSTOM_MAILBOX : Email::Mailbox::Constants::FRESHDESK_MAILBOX),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    response_pattern.merge!({ product_id: expected_output[:product_id] || mailbox.product_id }) if Account.current.multi_product_enabled?
    if freshdesk_mailbox?(mailbox)
      response_pattern.merge!(freshdesk_mailbox: { forward_email: mailbox.to_email })
    else
      response_pattern.merge!(custom_mailbox: custom_mailbox_hash(mailbox))
    end
    response_pattern
  end

  def freshdesk_mailbox?(mailbox)
    !custom_mailbox?(mailbox)
  end

  def custom_mailbox?(mailbox)
    mailbox.imap_mailbox.present? || mailbox.smtp_mailbox.present?
  end

  def custom_mailbox_hash(mailbox)
    result_hash = { access_type: access_type(mailbox) }
    result_hash.merge!({incoming: imap_mailbox_hash(mailbox)}) if mailbox.imap_mailbox.present?
    result_hash.merge!({outgoing: smtp_mailbox_hash(mailbox)}) if mailbox.smtp_mailbox.present?
    result_hash
  end

  def access_type(mailbox)
    type = if mailbox.imap_mailbox.present? && mailbox.smtp_mailbox.present?
             Email::Mailbox::Constants::BOTH_ACCESS_TYPE
           elsif mailbox.imap_mailbox.present?
             Email::Mailbox::Constants::INCOMING_ACCESS_TYPE
           else
             Email::Mailbox::Constants::OUTGOING_ACCESS_TYPE
           end
  end
  
  def imap_mailbox_hash(mailbox)
    result_hash = {}
    if mailbox.imap_mailbox.present?
      result_hash.merge!({
        mail_server: mailbox.imap_mailbox.server_name,
        port: mailbox.imap_mailbox.port,
        use_ssl: mailbox.imap_mailbox.use_ssl,
        delete_from_server: mailbox.imap_mailbox.delete_from_server,
        authentication: mailbox.imap_mailbox.authentication == Email::Mailbox::Constants::IMAP_CRAM_MD5 ? Email::Mailbox::Constants::CRAM_MD5 : mailbox.imap_mailbox.authentication,
        user_name: mailbox.imap_mailbox.user_name
        })
    end
    result_hash
  end
  
  def smtp_mailbox_hash(mailbox)
    result_hash = {}
    if mailbox.smtp_mailbox.present?
      result_hash.merge!({
        mail_server: mailbox.smtp_mailbox.server_name,
        port: mailbox.smtp_mailbox.port,
        use_ssl: mailbox.smtp_mailbox.use_ssl,
        authentication: mailbox.smtp_mailbox.authentication,
        user_name: mailbox.smtp_mailbox.user_name
        })
    end
    result_hash    
  end

  def create_email_config(options = {})
    email_config_params = {
      name: options[:name] || Faker::Name.name,
      reply_email: options[:support_email] || "#{Faker::Internet.email}",
      primary_role: options[:default_reply_email] || false,
      active: options[:active] || true,
      group_id: options[:group_id],
      product_id: options[:product_id]
    }
    test_email_config = FactoryGirl.build(:email_config, email_config_params)
    test_email_config.save(validate: false)
    test_email_config
  end
  
  def create_custom_mailbox_hash(options = {})
    mailbox_access_type = options[:access_type] || 'incoming'
    result_hash = { access_type: mailbox_access_type }
    result_hash.merge!({incoming: create_incoming_type_hash(options)}) if [Email::Mailbox::Constants::INCOMING_ACCESS_TYPE, Email::Mailbox::Constants::BOTH_ACCESS_TYPE].include?(mailbox_access_type)
    result_hash.merge!({outgoing: create_outgoing_type_hash(options)}) if [Email::Mailbox::Constants::OUTGOING_ACCESS_TYPE, Email::Mailbox::Constants::BOTH_ACCESS_TYPE].include?(mailbox_access_type)
    { custom_mailbox: result_hash }
  end
  
  def create_incoming_type_hash(options = {})
    {
      mail_server: options[:imap_server_name] || 'imap.gmail.com',
      port: options[:imap_port] || 993,
      use_ssl: options[:imap_use_ssl] || true,
      delete_from_server: options[:imap_delete_from_server] || true,
      authentication: options[:imap_authentication] || 'plain',
      user_name: options[:imap_user_name] || 'smtp@gmail.com',
      password: options[:imap_password] || 'password'
    }
  end
  
  def create_outgoing_type_hash(options = {})
    {
      mail_server: options[:smtp_server_name] || 'smtp.gmail.com',
      port: options[:smtp_port] || 587,
      use_ssl: options[:smtp_use_ssl] || true,
      authentication: options[:smtp_authentication] || 'plain',
      user_name: options[:smtp_user_name] || 'smtp@gmail.com',
      password: options[:smtp_password] || 'password'
    }
  end
end

