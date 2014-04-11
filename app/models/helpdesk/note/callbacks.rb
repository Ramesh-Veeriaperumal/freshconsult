class Helpdesk::Note < ActiveRecord::Base

	before_create :validate_schema_less_note, :update_observer_events
  before_save :load_schema_less_note, :update_category, :load_note_body, :ticket_cc_email_backup

  after_create :update_content_ids, :update_parent, :add_activity, :fire_create_event               
  after_commit_on_create :update_ticket_states, :notify_ticket_monitor, :increment_notes_counter, :push_mobile_notification

  after_commit_on_create :update_es_index, :if => :human_note_for_ticket?
  after_commit_on_create :subscribe_event_create, :if => :api_webhook_note_check  
  after_commit_on_update :update_es_index, :if => :human_note_for_ticket?
  after_commit_on_destroy :remove_es_document

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

  protected

  	def validate_schema_less_note
      return unless human_note_for_ticket?
      
      if email_conversation?
        if schema_less_note.to_emails.blank?
          schema_less_note.to_emails = notable.requester.email 
          schema_less_note.from_email ||= account.primary_email_config.reply_email
        end
        schema_less_note.to_emails = fetch_valid_emails(schema_less_note.to_emails)
        schema_less_note.cc_emails = fetch_valid_emails(schema_less_note.cc_emails)
        schema_less_note.bcc_emails = fetch_valid_emails(schema_less_note.bcc_emails)
      elsif note?
        schema_less_note.to_emails = fetch_valid_emails(schema_less_note.to_emails)
      end
    end

    def update_content_ids
      header = self.header_info
      return if attachments.empty? or header.nil? or header[:content_ids].blank?
      
      attachments.each do |attach| 
        content_id = header[:content_ids][attach.content_file_name]
        self.note_body.body_html = self.note_body.body_html.sub("cid:#{content_id}", attach.content.url) if content_id
      end
      
      # note_body.update_attribute(:body_html,self.note_body.body_html)
      # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
      #Helpdesk::Note.update_all("note_body.body_html= #{ActiveRecord::Base.connection.quote(body_html)}", ["id=? and account_id=?", id, account_id]) if body_html_changed?
    end

    def update_parent #Maybe after_save?!
      return unless human_note_for_ticket?
      
      if user.customer?
        # Ticket re-opening, moved as an observer's default rule
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::REPLIED_BY_REQUESTER)
        Helpdesk::TicketNotifier.send_later(:notify_by_email, (EmailNotification::REPLIED_BY_REQUESTER),
                                              notable, self) if notable.responder && e_notification.agent_notification?
      else    
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)     
        #notify the agents only for notes
        if note? && !self.to_emails.blank? && !incoming
          Helpdesk::TicketNotifier.send_later(:deliver_notify_comment, notable, self ,notable.friendly_reply_email,{:notify_emails =>self.to_emails}) unless self.to_emails.blank? 
        end
        #notify the customer if it is public note
        if note? && !private && e_notification.requester_notification?
        Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT,      
           notable, self)
        #handle the email conversion either fwd email or reply
        elsif email_conversation?
          send_reply_email
          create_fwd_note_activity(self.to_emails) if fwd_email?
        end

        # notable.responder ||= self.user unless private_note? # Added as a default observer rule
        
      end
      # syntax to move code from delayed jobs to resque.
      #Resque::MyNotifier.deliver_reply( notable.id, self.id , {:include_cc => true})
      notable.updated_at = created_at
      notable.cc_email_will_change! if notable_cc_email_updated?(@prev_cc_email, notable.cc_email)
      notable.save
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

    def update_category
      schema_less_note.category = CATEGORIES[:meta_response]
      return unless human_note_for_ticket?

      if user.customer?
        schema_less_note.category = replied_by_third_party? ? CATEGORIES[:third_party_response] : 
          CATEGORIES[:customer_response]
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

    def update_ticket_states
      Resque.enqueue(Helpdesk::UpdateTicketStates, 
            { :id => id, :model_changes => @model_changes,
              :freshdesk_webhook => freshdesk_webhook? }) unless zendesk_import?
    end

	def push_mobile_notification
    	message = { :ticket_id => notable.display_id,
                  :status_name => notable.status_name,
                  :subject => truncate(notable.subject, :length => 100),
                  :priority => notable.priority }
		  send_mobile_notification(:response,message)
	end

    def notify_ticket_monitor
      notable.subscriptions.each do |subscription|
        if subscription.user.id != user_id
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
      if user && user.customer? || !note?
        @model_changes = {:reply_sent => :sent}
      else
        @model_changes = {:note_type => NOTE_TYPE[private]}
      end
    end

    def increment_notes_counter
      time = Time.now.utc
      value = $stats_redis.incr "stats:tickets:#{time.day}:notes:#{time.hour}:#{self.user_id}:#{self.account_id}"
      if value == 1
        $stats_redis.expire "stats:tickets:#{time.day}:notes:#{time.hour}:#{self.user_id}:#{self.account_id}", 144000
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end


    def api_webhook_note_check
      (notable.instance_of? Helpdesk::Ticket) && !meta? && allow_api_webhook?
    end

end
