module Users
  module Activator

    def reset_agent_password(portal = nil)
      clear_password_field
      deliver_password_reset_instructions!(portal)
    end


    def deliver_password_reset_instructions!(portal)
      portal ||= account.main_portal
      reply_email = portal.main_portal ? account.default_friendly_email : portal.friendly_email 
      reset_perishable_token!

      e_notification = account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET)
      if customer?
        requester_template = e_notification.get_requester_template(self)
        template = requester_template.last
        subj_template = requester_template.first
        user_key = 'contact'
      else
        agent_template = e_notification.get_agent_template(self)
        template = agent_template.last
        subj_template = agent_template.first
      end

      UserNotifier.send_later(:deliver_password_reset_instructions, self, 
        :email_body => Liquid::Template.parse(template).render((user_key ||= 'agent') => self, 
          'helpdesk_name' => (!portal.name.blank?) ? portal.name : account.portal_name, 
          'password_reset_url' => edit_password_reset_url(perishable_token, 
            :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host, :protocol=> url_protocol)), 
          :subject => Liquid::Template.parse(subj_template).render('portal_name' => (!portal.name.blank?) ? portal.name : account.portal_name) ,:reply_email => reply_email)
    end
    
    def deliver_activation_instructions!(portal, force_notification, email_config = nil) #Need to refactor this.. Almost similar structure with the above one.
      portal ||= account.main_portal
      reply_email = email_config ? email_config.friendly_email : 
                      (portal.main_portal ? account.default_friendly_email : portal.friendly_email)
      reset_perishable_token!

      e_notification = account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
      if customer?
        return unless e_notification.requester_notification? or force_notification
        requester_template = e_notification.get_requester_template(self)
        template = requester_template.last
        subj_template = requester_template.first
        user_key = 'contact'
      else
        return unless e_notification.agent_notification?
        agent_template = e_notification.get_agent_template(self)
        template = agent_template.last
        subj_template = agent_template.first
      end
      activation_params = { :email_body => Liquid::Template.parse(template).render((user_key ||= 'agent') => self, 
                                  'helpdesk_name' =>  (!portal.name.blank?) ? portal.name : account.portal_name, 
                                  'activation_url' => register_url(perishable_token, 
                                                          :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host, 
                                                          :protocol=> url_protocol)), 
                            :subject => Liquid::Template.parse(subj_template).render(
                                  'portal_name' => (!portal.name.blank?) ? portal.name : account.portal_name) , 
                            :reply_email => reply_email}
      UserNotifier.send_later(:deliver_user_activation, self, activation_params)
    end
    
    def deliver_contact_activation(portal)
      portal ||= account.main_portal
      reply_email = portal.main_portal ? account.default_friendly_email : portal.friendly_email
      unless active?
        reset_perishable_token!
    
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
        requester_template = e_notification.get_requester_template(self)
        UserNotifier.send_later(:deliver_user_activation, self, 
            :email_body => Liquid::Template.parse(requester_template.last).render('contact' => self, 
              'helpdesk_name' =>  (!portal.name.blank?) ? portal.name : account.portal_name , 'activation_url' => register_url(perishable_token, :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host, :protocol=> url_protocol)), 
            :subject => Liquid::Template.parse(e_notification.requester_template.first).render , :reply_email => reply_email)
      end
    end
  
    def deliver_admin_activation
      UserNotifier.send_later(:deliver_admin_activation,self)
    end

    private

    def clear_password_field
      self.crypted_password = nil
      self.password_salt = nil
      save
    end
  end
end