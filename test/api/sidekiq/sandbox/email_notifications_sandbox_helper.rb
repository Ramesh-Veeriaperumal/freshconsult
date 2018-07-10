module EmailNotificationsSandboxHelper
  MODEL_NAME = Account.reflections["email_notifications".to_sym].klass.new.class.name 
  ACTIONS = ['conflict', 'delete', 'update', 'create']

  def email_notifications_data(account)
    all_email_notifications_data = []
    ACTIONS.each do |action|
      all_email_notifications_data << send("#{action}_email_notifications_data", account)
    end
    all_email_notifications_data.flatten
  end

  def create_email_notifications_data(account)
    email_notifications_data = []
    # 3.times do
    #   email_notification = create_email_notification(account)
    #   email_notifications_data << email_notification.attributes.merge("model" => MODEL_NAME, "action" => "added")
    # end
    # email_notifications_data
  end

  def update_email_notifications_data(account)
    email_notification = account.email_notifications.first
    return [] unless email_notification
    email_notification.notification_type = 25
    changed_attr = email_notification.changes
    email_notification.save
    [Hash[changed_attr.map {|k,v| [k,v[1]]}].merge("id"=> email_notification.id).merge("model" => MODEL_NAME, "action" => "modified")]
  end

  def delete_email_notifications_data(account)
    email_notification = account.email_notifications.first
    return [] unless email_notification
    email_notification.destroy
    [email_notification.attributes.merge("model" => MODEL_NAME, "action" => "deleted")]
  end

  def conflict_email_notifications_data(account)
    email_notification = account.email_notifications.find_by_notification_type(101)
    return [] unless email_notification
    email_notification.notification_type = 102
    email_notification.save
    email_notification.attributes.merge("model" => MODEL_NAME, "action" => "conflict")
  end

  def create_email_notifications_data_for_conflict(account)
    create_email_notification(account, notification_type: 101) # production data for conflict
  end

  def create_conflict_email_notifications_in_production(account)
    email_notification = account.email_notifications.find_by_notification_type(101)
    return [] unless email_notification
    email_notification.notification_type = 115
    email_notification.save
  end

  def create_email_notification(account, params = {})
    options = {:notification_type => params[:notification_type] || (account.email_notifications.last.id + 30), :requester_notification => false, :agent_notification => false, 
      :agent_template => "test", :agent_subject_template => Faker::Lorem.sentence(3)}
    test_email_notification = EmailNotification.create(options)
    test_email_notification.save(validate: false)
    test_email_notification
  end
end
