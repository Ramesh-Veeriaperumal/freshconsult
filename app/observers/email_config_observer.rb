class EmailConfigObserver < ActiveRecord::Observer
    
  def before_validation(email_config)
    if email_config.new_record?
     set_account email_config
    end
    email_config
  end

  def before_create(email_config)
    set_name email_config
    mark_as_primary email_config
    email_config.set_activator_token
  end

  def after_commit(email_config)
    deliver_email_activation email_config if !destroy?(email_config) && custom_mailbox?(email_config)
  end

  def before_update(email_config)
    mark_as_primary email_config
    email_config.reset_activator_token
  end

  #Methods used for the callbacks

  def set_account(email_config)
    email_config.account_id ||= Account.current.id if Account.current
  end

  def set_name(email_config)
    email_config.name = (email_config.name.blank? && email_config.product) ? email_config.product.name : email_config.name
  end

  def mark_as_primary(email_config)
    if email_config.changed.include?("primary_role") && email_config.primary_role?
      old_primary_email_config = email_config.product ? email_config.product.primary_email_config : email_config.account.primary_email_config
      old_primary_email_config.update_attributes(:primary_role => false) if old_primary_email_config && !old_primary_email_config.new_record?
    end
  end

  def deliver_email_activation(email_config)
    if ( !email_config.active?) && (email_config.previous_changes.key?("reply_email") || email_config.previous_changes.key?("activator_token") )
      EmailConfigNotifier.send_later(:deliver_activation_instructions, email_config)
    end
  end

  private

    def custom_mailbox?(email_config)
      email_config.imap_mailbox.present? || email_config.smtp_mailbox.present?
    end

    def destroy?(email_config)
      email_config.safe_send(:transaction_include_action?, :destroy)
    end
end
