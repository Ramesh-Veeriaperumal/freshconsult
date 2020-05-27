class Security::AgentNotificationObserver < ActiveRecord::Observer
  observe User

  include SecurityNotification

  USER_ALERT_ATTRIBUTES = {
    "phone"               => "Phone number",
    "mobile"              => "Mobile number",
    "crypted_password"    => "Password",
    "single_access_token" => "API key"
  }

  WITH_FRESHID_V2_USER_ALERT_ATTRIBUTES = { "single_access_token" => "API key" }

  def after_commit(user)
    if user.safe_send(:transaction_include_action?, :update)
      if user.agent?
        alert_attributes = user_alert_attributes(user)
        changed_attributes = user.previous_changes.keys & alert_attributes.keys
        changed_attributes.select!{|attribute| attribute_changed?(user.previous_changes, attribute)}
        unless changed_attributes.empty?
          return if skip_notification?(user)
          changed_attributes_names = changed_attributes.map{ |i| alert_attributes[i] }
          SecurityEmailNotification.send_later(:deliver_agent_update_alert, user, changed_attributes_names,
            { locale_object: user })
        end
      end
    end
    true
  end

  private

    def skip_notification?(user)
      freshid_migration_in_progress = get_others_redis_key(format(SUPPRESS_FRESHID_V1_MIG_AGENT_NOTIFICATION, account_id: user.account.id.to_s))
      user_changes = user.previous_changes
      return true if (user_changes.keys.include?('crypted_password') && user_changes['crypted_password'][0].nil?) || freshid_migration_in_progress
    end
  
  def attribute_changed?(user_changes, attribute)
    user_changes.keys.include?(attribute) and !(user_changes[attribute][0].blank? and user_changes[attribute][1].blank?)
  end

  def user_alert_attributes(user)
    user.account.freshid_org_v2_enabled? ? WITH_FRESHID_V2_USER_ALERT_ATTRIBUTES : USER_ALERT_ATTRIBUTES
  end

end
