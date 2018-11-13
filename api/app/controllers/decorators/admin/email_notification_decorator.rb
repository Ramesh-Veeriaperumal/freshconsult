class Admin::EmailNotificationDecorator < ApiDecorator
  delegate :notification_type, :requester_notification, :requester_subject_template, :requester_template, 
  :agent_notification, :agent_subject_template, :agent_template, to: :record

  def to_hash
    {
      id: notification_type,
      requester_notification: requester_notification,
      requester_subject_template: requester_subject_template,
      requester_template: requester_template,
      agent_notification: agent_notification,
      agent_subject_template: agent_subject_template,
      agent_template: agent_template
    }
  end
end
