module Helpdesk::TicketNotifications
	def self.included(base)
		base.send :include, InstanceMethods
	end

	module InstanceMethods

		include Helpdesk::Ticketfields::TicketStatus
		
		def autoreply     
      #dont send email if user creates ticket by "save and close"
      return if spam? || deleted? || self.skip_notification? || closed_at.present? 
      notify_by_email(EmailNotification::NEW_TICKET)
      if Account.current.features?(:shared_ownership)
        notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_GROUP, true) if internal_group_id.present?
        notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_AGENT, true) if internal_agent_id.present?
      end

      notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_GROUP) if group_id and !group_id_changed?
      notify_by_email_without_delay(EmailNotification::TICKET_ASSIGNED_TO_AGENT) if responder_id and !responder_id_changed?
      
      unless status_changed?
        return notify_by_email_without_delay(EmailNotification::TICKET_RESOLVED) if resolved?
        return notify_by_email_without_delay(EmailNotification::TICKET_CLOSED) if closed?
      end
    end

  def notify_on_update
    return if spam? || deleted?
    if Account.current.features?(:shared_ownership)
      notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_GROUP, true) if internal_group_id_changed? && internal_group
      notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT, true) if send_agent_assigned_notification?(true)
    end
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
      if subscription.user.id != User.current.try(:id) 
        Helpdesk::WatcherNotifier.send_later(:deliver_notify_on_status_change, self,
                                              subscription, status, User.current.nil? ? "An automation rule" : "#{User.current.name}")
      end
    end
  end

  def notify_by_email_without_delay(notification_type, internal_notification = false)
    opts = {:internal_notification => internal_notification}
    Helpdesk::TicketNotifier.notify_by_email(notification_type, self, nil, opts) if notify_enabled?(notification_type)
  end
  
  def notify_by_email(notification_type, internal_notification = false)
    if notify_enabled?(notification_type)
      if (self.requester.language != nil)
        if self.send_and_set
          enqueue_notification(notification_type, 90.seconds.from_now, internal_notification)
        else
          Helpdesk::TicketNotifier.send_later(:notify_by_email, notification_type, self, nil, {:internal_notification => internal_notification})
        end
      else
        enqueue_notification(notification_type, 5.minutes.from_now, internal_notification)
      end
    end  
  end

  def enqueue_notification(notification_type, time, internal_notification)
    args = [notification_type, self, nil, {:internal_notification => internal_notification}]
    Delayed::Job.enqueue(Delayed::PerformableMethod.new(Helpdesk::TicketNotifier, :notify_by_email, args), 
          nil, time) 
  end

  def notify_enabled?(notification_type)
    e_notification = account.email_notifications.find_by_notification_type(notification_type)
    (e_notification.requester_notification? && !self.ecommerce?) or e_notification.agent_notification?
  end

  def send_outbound_email
    Helpdesk::TicketNotifier.send_later(:deliver_notify_outbound_email, self)
  end

	end
end