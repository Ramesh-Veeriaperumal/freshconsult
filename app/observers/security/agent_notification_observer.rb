class Security::AgentNotificationObserver < ActiveRecord::Observer
  observe User

  include SecurityNotification

  USER_ATTRIBUTES = {
    "phone"               => "Phone number",
    "mobile"              => "Mobile number",
    "crypted_password"    => "Password",
    "single_access_token" => "API key"
  }

  def after_commit(user)
    if user.safe_send(:transaction_include_action?, :update)
      if user.agent?
        changed_attributes = user.previous_changes.keys & USER_ATTRIBUTES.keys
        changed_attributes.select!{|attribute| attribute_changed?(user.previous_changes, attribute)}
        unless changed_attributes.empty?
          return if skip_notification?(user.previous_changes)
          changed_attributes_names = changed_attributes.map{ |i| USER_ATTRIBUTES[i] }
          subject = "Your #{changed_attributes_names.to_sentence} in #{user.account.name} has been updated"
          SecurityEmailNotification.send_later(:deliver_agent_alert_mail, user, subject, changed_attributes_names)
        end
      end
    end
    true
  end

  private

  def skip_notification?(user_changes)
    return true if user_changes.keys.include?("crypted_password") and user_changes["crypted_password"][0].nil?
  end
  
  def attribute_changed?(user_changes, attribute)
    user_changes.keys.include?(attribute) and !(user_changes[attribute][0].blank? and user_changes[attribute][1].blank?)
  end

end
