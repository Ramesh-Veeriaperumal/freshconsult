module Helpdesk::TicketNotifications
	def self.included(base)
		base.send :include, InstanceMethods
	end

	module InstanceMethods

		include Helpdesk::Ticketfields::TicketStatus
		
		def autoreply     
      return if spam? || deleted? || self.skip_notification?
      notify_by_email(EmailNotification::NEW_TICKET)
      notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if group_id and !group_id_changed?
      notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if responder_id and !responder_id_changed?
      
      unless status_changed?
        return notify_by_email_without_delay(EmailNotification::TICKET_RESOLVED) if resolved?
        return notify_by_email_without_delay(EmailNotification::TICKET_CLOSED) if closed?
      end
    end

  def notify_on_update
    return if spam? || deleted?
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if (@model_changes.key?(:group_id) && group)
    notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if send_agent_assigned_notification?
    
    if @model_changes.key?(:status)
      if (status == RESOLVED)
        notify_by_email(EmailNotification::TICKET_RESOLVED) 
        notify_watchers("resolved")
        return
      end
      if (status == CLOSED)
        notify_by_email(EmailNotification::TICKET_CLOSED)
        notify_watchers("closed")
        return
      end
    end
  end

  def notify_watchers(status)
    self.subscriptions.each do |subscription|
      if subscription.user.id != User.current.id
        Helpdesk::WatcherNotifier.send_later(:deliver_notify_on_status_change, self, 
                                              subscription, status, "#{User.current.name}")
      end
    end
  end

  def notify_by_email_without_delay(notification_type)    
    Helpdesk::TicketNotifier.notify_by_email(notification_type, self) if notify_enabled?(notification_type)
  end
  
  def notify_by_email(notification_type)
    Helpdesk::TicketNotifier.send_later(:notify_by_email, notification_type, self) if notify_enabled?(notification_type)
  end
  
  def notify_enabled?(notification_type)
    e_notification = account.email_notifications.find_by_notification_type(notification_type)
    e_notification.requester_notification? or e_notification.agent_notification?
  end

	end
end