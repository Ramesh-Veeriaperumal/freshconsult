class Helpdesk::Note < ActiveRecord::Base

  # rate_limit :rules => lambda{ |obj| Account.current.account_additional_settings_from_cache.resource_rlimit_conf['helpdesk_notes'] }, :if => lambda{|obj| obj.rl_enabled? }

  before_create :validate_schema_less_note, :update_observer_events
  before_save :load_schema_less_note, :update_category, :load_note_body, :ticket_cc_email_backup

  after_create :update_content_ids, :update_parent, :add_activity, :fire_create_event
  # Doing update note count before pushing to ticket_states queue
  # So that note count will be reflected if the rmq publish happens via ticket states queue
  after_commit ->(obj) { obj.send(:update_note_count_for_reports)  }, on: :create , :if => :report_note_metrics?
  after_commit :update_ticket_states, :notify_ticket_monitor, :push_mobile_notification, on: :create

  after_commit :send_notifications, on: :create, :if => :human_note_for_ticket?

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.update_es_index }, on: :create, :if => :human_note_for_ticket?
  after_commit ->(obj) { obj.update_es_index }, on: :update, :if => :human_note_for_ticket?

  after_commit ->(obj) { obj.send(:update_note_count_for_reports)  }, on: :destroy, :if => :report_note_metrics?

  after_commit :subscribe_event_create, on: :create, :if => :api_webhook_note_check
  after_commit :remove_es_document, on: :destroy, :if => :deleted_archive_note

  after_update ->(obj) { obj.notable.update_timestamp }, :if => :human_note_for_ticket?

  # Callbacks will be executed in the order in which they have been included.
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  # For using Redis related functionalities
  include Redis::RedisKeys
  include Redis::OthersRedis

  def construct_note_old_body_hash
    {
      :body => self.note_body_content.body,
      :body_html => self.note_body_content.body_html,
      :full_text => self.note_body_content.full_text,
      :full_text_html => self.note_body_content.full_text_html,
      :raw_text => self.note_body_content.raw_text,
      :raw_html => self.note_body_content.raw_html,
      :meta_info => self.note_body_content.meta_info,
      :version => self.note_body_content.version,
      :account_id => self.account_id,
      :note_id => self.id
    }
  end

  def load_full_text
    self.note_body.full_text ||= note_body.body unless note_body.body.blank?
    self.note_body.full_text_html ||= note_body.body_html unless note_body.body_html.blank?
    if self.note && self.note.note? && !self.note.incoming  # for updating full_text content if body_html is edited
      self.note_body.full_text = note_body.body unless note_body.body.blank?
      self.note_body.full_text_html = note_body.body_html unless note_body.body_html.blank?
    end
  end

  def remove_activity
    if outbound_email?
      unless private?
        notable.destroy_activity('activities.tickets.conversation.out_email.long', id)
      end
    elsif inbound_email?
      notable.destroy_activity('activities.tickets.conversation.in_email.long', id)
    else
      notable.destroy_activity("activities.tickets.conversation.#{ACTIVITIES_HASH.fetch(source, "note")}.long", id)
    end
  end

  protected

  	def validate_schema_less_note
      return unless human_note_for_ticket?
      emails = [schema_less_note.to_emails, schema_less_note.bcc_emails]
      if email_conversation?
        if schema_less_note.to_emails.blank?
          schema_less_note.to_emails = notable.from_email
          schema_less_note.from_email ||= account.primary_email_config.reply_email
        end
        schema_less_note.to_emails = fetch_valid_emails(schema_less_note.to_emails)
        schema_less_note.bcc_emails = fetch_valid_emails(schema_less_note.bcc_emails)
      elsif reply_to_forward?
        schema_less_note.to_emails, schema_less_note.bcc_emails = reset_emails(emails)
      elsif note?
        schema_less_note.to_emails = fetch_valid_emails(schema_less_note.to_emails)
      end
      schema_less_note.cc_emails = format_cc_emails_hash
    end

    def update_content_ids
      header = self.header_info
      return if inline_attachments.empty? or header.nil? or header[:content_ids].blank?
      
      inline_attachments.each_with_index do |attach, index| 
        content_id = header[:content_ids][attach.content_file_name+"#{index}"]
        self.note_body.body_html = self.note_body.body_html.sub("cid:#{content_id}", attach.content.url) if content_id
        self.note_body.full_text_html = self.note_body.full_text_html.sub("cid:#{content_id}", attach.content.url) if content_id
      end
      
      # note_body.update_attribute(:body_html,self.note_body.body_html)
      # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
      #Helpdesk::Note.update_all("note_body.body_html= #{ActiveRecord::Base.connection.quote(body_html)}", ["id=? and account_id=?", id, account_id]) if body_html_changed?
    end

    def update_parent #Maybe after_save?!
      return unless human_note_for_ticket?
      # syntax to move code from delayed jobs to resque.
      #Resque::MyNotifier.deliver_reply( notable.id, self.id , {:include_cc => true})
      notable.updated_at = created_at
      add_cc_email  if (email_conversation? and !user.customer?) || reply_to_forward?
      add_client_manager_cc if performed_by_client_manager?
      # notable.cc_email_will_change! if notable_cc_email_updated?(@prev_cc_email, notable.cc_email)
      notable.trigger_cc_changes(@prev_cc_email)
      notable.save
    end

    def send_notifications
      return if skip_notification
      if notable.customer_performed?(user)
        # Ticket re-opening, moved as an observer's default rule
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::REPLIED_BY_REQUESTER)
        Helpdesk::TicketNotifier.send_later(:notify_by_email, (EmailNotification::REPLIED_BY_REQUESTER),
                                              notable, self) if notable.responder && e_notification.agent_notification? && replied_by_customer?
        if public_note? 
          if performed_by_client_manager?
            Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT, notable, self)
          end
          if notable.cc_email.present?
            if user.id == notable.requester_id
              Helpdesk::TicketNotifier.send_later(:send_cc_email, notable , self, {})
            elsif notable.included_in_cc?(user.email)
              additional_emails = [notable.requester.email] unless performed_by_client_manager?
              # Using cc notification to send notification to requester about new comment by cc
              Helpdesk::TicketNotifier.send_later(:send_cc_email, notable , self, {:additional_emails => additional_emails,
                                                                                   :ignore_emails => [user.email]})
            end
          end
        end
        handle_notification_for_agent_as_req if ( !incoming && notable.agent_as_requester?(user.id))
      else    
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)     
        #notify the agents only for notes
        notifying_agents
        #notify the customer if it is public note
        if note? && !private && e_notification.requester_notification?
        Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT, notable, self)
        Helpdesk::TicketNotifier.send_later(:send_cc_email, notable , self, {}) if notable.cc_email.present?
        #handle the email conversion either fwd email or reply
        elsif email_conversation?
          send_reply_email
          create_fwd_note_activity(self.to_emails) if fwd_email?
        end

        # notable.responder ||= self.user unless private_note? # Added as a default observer rule

      end
    end

    def handle_notification_for_agent_as_req
      # Send the notifications to the notified agents when agent as a requester adds a note (pvt/public)
      notifying_agents
      # Send the replies to requester and cc person, when agent as a requester replies from the helpdesk agent portal
      if email? && (self.to_emails.present? || self.cc_emails.present? || self.bcc_emails.present?)
        Helpdesk::TicketNotifier.send_later(:deliver_reply, notable, self, {:include_cc => self.cc_emails.present? ,
                :send_survey => false,
                :quoted_text => self.quoted_text,
                :include_surveymonkey_link => false})
      end
      # Forward case
      if fwd_email?
        Helpdesk::TicketNotifier.send_later(:deliver_forward, notable, self) unless only_kbase?
        create_fwd_note_activity(self.to_emails)
      end
    end

    def notifying_agents
      if note? && !self.to_emails.blank? && !incoming 
        if reply_to_forward?
          Helpdesk::TicketNotifier.send_later(:deliver_reply_to_forward, notable, self)
        else
          Helpdesk::TicketNotifier.send_later(:notify_comment, self)
        end
      end
    end


    def add_activity
      return if (!human_note_for_ticket? or zendesk_import?)

      if outbound_email?
        unless private?
          notable.create_activity(user, 'activities.tickets.conversation.out_email.long',
            {'eval_args' => {'reply_path' => ['reply_path',
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
            'activities.tickets.conversation.out_email.short')
        end
      elsif inbound_email?
        notable.create_activity(user, 'activities.tickets.conversation.in_email.long',
          {'eval_args' => {'email_response_path' => ['email_response_path',
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          'activities.tickets.conversation.in_email.short')
      else
        notable.create_activity(user, "activities.tickets.conversation.#{ACTIVITIES_HASH.fetch(source, "note")}.long",
          {'eval_args' => {"#{ACTIVITIES_HASH.fetch(source, "comment")}_path" => ["#{ACTIVITIES_HASH.fetch(source, "comment")}_path",
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          "activities.tickets.conversation.#{ACTIVITIES_HASH.fetch(source, "note")}.short")
      end
    end

  private

    def load_schema_less_note
      build_schema_less_note unless schema_less_note
      schema_less_note
    end

    # IMP: Whenever new category is added, it must be handled in reports
    def update_category
      return if schema_less_note.category
      schema_less_note.category = CATEGORIES[:meta_response]
      return unless human_note_for_ticket?
      return schema_less_note.category = CATEGORIES[:customer_feedback] if self.feedback?

      if notable.customer_performed?(user)
        schema_less_note.category = case 
        when replied_by_third_party?
          CATEGORIES[:third_party_response]
        when private? && notable.agent_as_requester?(user.id)
          CATEGORIES[:agent_private_response]
        else
          CATEGORIES[:customer_response]
        end
      else
        schema_less_note.category = private? ? CATEGORIES[:agent_private_response] :
          CATEGORIES[:agent_public_response]
      end
    end

    def load_note_body
      build_note_body(:body => self.body, :body_html => self.body_html) unless note_body
    end

    def fire_create_event
      fire_event(:create) unless disable_observer
    end

    def reset_emails(emails_array)
      emails_array.map{|emails| fetch_valid_emails(emails)}
    end

    def update_ticket_states
      user_id = User.current.id if User.current
      Tickets::UpdateTicketStatesWorker.perform_async(
            { :id => id, :model_changes => @model_changes,
              :freshdesk_webhook => freshdesk_webhook?,
              :current_user_id =>  user_id }
            ) unless zendesk_import?
    end

	def push_mobile_notification

    	message = { :ticket_id => notable.display_id,
                  :status_name => notable.status_name,
                  :subject => truncate(notable.subject, :length => 100),
                  :priority => notable.priority,
                  :time => created_at.to_i }
		  send_mobile_notification(:response,message) unless notable.spam? || notable.deleted?
	end

    def notify_ticket_monitor
      return if meta?
      notable.subscriptions.each do |subscription|
        if subscription.user_id != user_id
          Helpdesk::WatcherNotifier.send_later(:deliver_notify_on_reply,
                                                notable, subscription, self)
        end
      end
    end

    def ticket_cc_email_backup
      @prev_cc_email = notable.cc_email.dup unless notable.cc_email.nil?
    end
		
    # VA - Observer Rule 
    def update_observer_events
      return if user.nil? || meta? || feedback? || !(notable.instance_of? Helpdesk::Ticket)
      if replied_by_customer? || replied_by_agent?
        @model_changes = {:reply_sent => :sent}
      else
        @model_changes = {:note_type => NOTE_TYPE[private]}
      end
    end

    def replied_by_customer?
      # Added the private note check when agent as a requester adds a private note should not trigger the observer rule
      # (Should behave as a private note)
      (user.customer? || (notable.agent_as_requester?(user.id) && (public_note? || email?)))
    end

    def replied_by_agent?
      # Should not trigger the reply sent observer rule - when the forward/reply to forward is made
      ( !note? && !fwd_email? && !reply_to_forward? )
    end
 
    def api_webhook_note_check
      (notable.instance_of? Helpdesk::Ticket) && !meta? && allow_api_webhook? && !notable.spam_or_deleted?
    end
    
    ##### ****** Methods related to reports starts here ******* #####
    def update_note_count_for_reports
      return if notable.blank? || notable.frozen? # Added frozen check because when ticket is destoyed, note gets destroyed and notable will be frozen. So cant modify schema_less_ticket.
      action = model_transaction_action
      return if action == "update" # Dont reduce the count when the note is deleted from UI (Soft delete)
      return if action == "destroy" && notable.archive # Dont reduce the count if destroy happens because its moved to archive
      note_category = reports_note_category
      if note_category && Helpdesk::SchemaLessTicket::COUNT_COLUMNS_FOR_REPORTS.include?(note_category)
        notable.schema_less_ticket.send("update_#{note_category}_count", action)
        notable.schema_less_ticket.save
      end
    end
    
    # This can be put in a separate module and can be included wherever needed.
    # This remains common for all active record transactions
    def model_transaction_action
      if self.send(:transaction_include_action?, :create)
        action = "create"
      elsif self.send(:transaction_include_action?, :update)
        action = "update"
      elsif self.send(:transaction_include_action?, :destroy)
        action = "destroy"
      end 
    end
    
    def reports_note_category
      case schema_less_note.category
      when CATEGORIES[:customer_response]
        "customer_reply"
      # Only agent added pvt notes, fwds and reply to fwd will be counted as pvt note
      when CATEGORIES[:agent_private_response], CATEGORIES[:reply_to_forward]
        "private_note"
      when CATEGORIES[:agent_public_response]
        (note? ? "public_note" : "agent_reply")
      else
        Rails.logger.debug "Undefined note category #{schema_less_note.category}"
      end
    end
    
    def report_note_metrics?
      human_note_for_ticket? && !feedback?
    end
    ######## ****** Methods related to reports ends here ******** #####
    

    # preventing deletion from elastic search
    def deleted_archive_note
      if Account.current.features?(:archive_tickets) && self.notable && self.notable.archive
        return false
      end
      return true
    end

    def format_cc_emails_hash
      {   :cc_emails => fetch_valid_emails(schema_less_note.cc_emails_hash[:cc_emails]),
          :dropped_cc_emails => fetch_valid_emails(schema_less_note.cc_emails_hash[:dropped_cc_emails]) 
        }
    end

    def add_client_manager_cc
      notable.cc_email[:reply_cc] << user.email unless notable.cc_email[:reply_cc].include?(user.email)
      notable.cc_email[:cc_emails] << user.email unless notable.cc_email[:cc_emails].include?(user.email)
    end

    def performed_by_client_manager?
      public_note? && notable.customer_performed?(user) && user.has_customer_ticket_permission?(notable) && (user.id != notable.requester_id)
    end

end
