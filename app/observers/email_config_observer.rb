class EmailConfigObserver < ActiveRecord::Observer

  include CRM::TotangoModulesAndActions
    
  def before_validation_on_create(email_config)
    set_account email_config
  end

  def before_create(email_config)
    set_name email_config
    mark_as_primary email_config
    email_config.set_activator_token
  end

  def after_save(email_config)
    deliver_email_activation email_config
  end

  def before_update(email_config)
    mark_as_primary email_config
    email_config.reset_activator_token
  end

  def after_update(email_config)
    notify_totango email_config unless email_config.changes.blank?
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
    if ( !email_config.active?) && (email_config.changed.include?("reply_email") || email_config.changed.include?("activator_token") )
      EmailConfigNotifier.send_later(:deliver_activation_instructions, email_config)
    end
  end

  def notify_totango(email_config)
    Resque::enqueue(CRM::Totango::SendUserAction,
                                        {:account_id => email_config.account_id, 
                                         :email =>  email_config.account.account_admin.email, 
                                         :activity =>  totango_activity(:email_config) })
  end
end
