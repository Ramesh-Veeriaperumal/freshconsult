module Users
  module Activator

    include ActionView::Helpers
    include ActionDispatch::Routing
    include Rails.application.routes.url_helpers

    def reset_agent_password(portal = nil)
      clear_password_field
      deliver_password_reset_instructions!(portal)
    end

    def deliver_password_reset_instructions!(portal)
      return if agent? && Account.current.freshid_integration_enabled?
      portal = Portal.current || account.main_portal
      reply_email = portal.main_portal ? account.default_friendly_email : portal.friendly_email 
      email_config = portal.main_portal ? account.primary_email_config : portal.primary_email_config
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
        {:email_body => Liquid::Template.parse(template).render((user_key ||= 'agent') => self, 'helpdesk_name' => account.helpdesk_name, 
          'password_reset_url' => edit_password_reset_url(perishable_token, :host => host(portal), :protocol => url_protocol)), 
         :subject => Liquid::Template.parse(subj_template).render('portal_name' => (!portal.name.blank?) ? portal.name : account.portal_name) ,
         :reply_email => reply_email
        }, email_config )
    end
    
    def deliver_activation_instructions!(portal, force_notification, email_config = nil) #Need to refactor this.. Almost similar structure with the above one.
      portal = Portal.current || account.main_portal_from_cache
      reply_email = email_config ? email_config.friendly_email : 
                      (portal.main_portal ? account.default_friendly_email : portal.friendly_email)
      email_config = email_config ? email_config : 
                      (portal.main_portal ? account.primary_email_config : portal.primary_email_config)                      

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

      reset_perishable_token! unless perishable_token_reset

      activation_url = generate_activation_url(portal)
      activation_params = { :email_body => Liquid::Template.parse(template).render((user_key ||= 'agent') => self, 
                                  'helpdesk_name' =>  account.helpdesk_name, 
                                  'activation_url' => activation_url,
                                  'portal_name' => (!portal.name.blank?) ? portal.name : account.portal_name),
                            :subject => Liquid::Template.parse(subj_template).render(
                                  'portal_name' => (!portal.name.blank?) ? portal.name : account.portal_name) , 
                            :reply_email => reply_email,
                            :activation_url => activation_url
                          }
      UserNotifier.send_later(:deliver_user_activation, self, activation_params, email_config)
    end
    
    def deliver_agent_invitation!(portal=nil)
      portal = Portal.current || account.main_portal_from_cache
      reply_email = portal.main_portal ? account.default_friendly_email : portal.friendly_email 
      email_config = portal.main_portal ? account.primary_email_config : portal.primary_email_config
      
      e_notification = account.email_notifications.find_by_notification_type(EmailNotification::AGENT_INVITATION)
      agent_template = e_notification.get_agent_template(self)
      template = agent_template.last
      subject_template = agent_template.first
      params = {
        :email_body => Liquid::Template.parse(template).render('agent' => self, 'helpdesk_name' => account.helpdesk_name, 'helpdesk_url' => helpdesk_dashboard_url({host: host(portal), protocol: account.url_protocol})),
        :subject => Liquid::Template.parse(subject_template).render('portal_name' => (!portal.name.blank?) ? portal.name : account.portal_name),
        :reply_email => reply_email
      }
      UserNotifier.send_later(:deliver_agent_invitation, self, params, email_config)
    end
    
    def deliver_contact_activation(portal)
      portal ||= account.main_portal
      reply_email = portal.main_portal ? account.default_friendly_email : portal.friendly_email
      email_config = portal.main_portal ? account.primary_email_config : portal.primary_email_config
      unless active?
        reset_perishable_token!
    
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
        requester_template = e_notification.get_requester_template(self)
        activation_url = register_url(perishable_token, :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host, :protocol => url_protocol)
        UserNotifier.send_later(:deliver_user_activation, self,
          { :email_body => Liquid::Template.parse(e_notification.requester_template).render('contact' => self, 
              'helpdesk_name' =>  account.helpdesk_name , 'activation_url' => activation_url),
            :subject => Liquid::Template.parse(e_notification.requester_subject_template).render , 
            :reply_email => reply_email,
            :activation_url => activation_url
          },
          email_config)
      end
    end

    def deliver_contact_activation_email(portal=nil)
      portal = Portal.current || account.main_portal
      reply_email = portal.main_portal ? account.default_friendly_email : portal.friendly_email
      email_config = portal.main_portal ? account.primary_email_config : portal.primary_email_config
      @user = self.user
      unless verified?
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::ADDITIONAL_EMAIL_VERIFICATION)
        return unless e_notification.requester_notification? and @user.customer?
        activation_url = register_new_email_url(perishable_token, :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host, :protocol=> @user.url_protocol)
        UserNotifier.send_later(:deliver_email_activation, self,
            {
              :email_body => Liquid::Template.parse(e_notification.requester_template).render('contact' => @user,
                'helpdesk_name' =>  account.helpdesk_name , 'email' => self.email, 'activation_url' => activation_url),
              :subject => Liquid::Template.parse(e_notification.requester_subject_template).render('helpdesk_name' =>  account.helpdesk_name) , :reply_email => reply_email,
              :activation_url => activation_url
            }, email_config)
      end
    end
  
    def deliver_admin_activation
      UserNotifier.send_later(:deliver_admin_activation,self) unless Account.current.freshid_integration_enabled?
    end

    def restrict_domain
      if self.account.features_included?(:domain_restricted_access)
        domain = (/@(.+)/).match(self.email).to_a[1]
        wl_domain  = account.account_additional_settings_from_cache.additional_settings[:whitelisted_domain]
        unless Array.wrap(wl_domain).include?(domain)
          errors.add(:base, t(:'flash.g_app.domain_restriction')) and return false
        end
      end
    end

    private
 
    def generate_activation_url(portal)
      url = ""
      if agent? && Account.current.freshid_integration_enabled?
        host_info = { host: host(portal), protocol: url_protocol }
        redirect_url = (Account.current.agent_oauth2_sso_enabled? || Account.current.agent_freshid_saml_sso_enabled? ? agent_login_url(host_info) : helpdesk_dashboard_url(host_info))
        url =  generate_freshid_activation_hash(redirect_url) if self.freshid_authorization.present?
        Rails.logger.error "FRESHID Activation url is empty :: uid = #{self.id}, auth = #{self.freshid_authorization.inspect}" if url.blank?
      else
        url = register_url(perishable_token, :host => host(portal), :protocol => url_protocol)
      end
      url
    end

    def generate_freshid_activation_hash(redirect_url)
      if Account.current.freshid_org_v2_enabled?
        url = Freshid::V2::Models::UserHash.create_activation_hash(self.freshid_authorization.uid, redirect_url, Account.current.organisation_domain)
        url.try(:dup)
      else
        Freshid::User.generate_activation_url(redirect_url, self.freshid_authorization.uid)
      end
    end
  
    def host(portal)
      portal.portal_url.present? ? portal.portal_url : account.host
    end

    def clear_password_field
      self.crypted_password = nil
      self.password_salt = nil
      save
    end
  end
end