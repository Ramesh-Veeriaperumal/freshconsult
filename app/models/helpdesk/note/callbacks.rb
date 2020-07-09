class Helpdesk::Note < ActiveRecord::Base

  # rate_limit :rules => lambda{ |obj| Account.current.account_additional_settings_from_cache.resource_rlimit_conf['helpdesk_notes'] }, :if => lambda{|obj| obj.rl_enabled? }

  # Any changes related to note or reply made in this file should be replicated in
  # send_and_set_helper if required
  before_create :update_observer_events
  before_create :create_broadcast_message, :if => :broadcast_note?
  before_save :update_parent_sender_email, :if => :email?
  before_save :load_schema_less_note, :update_category, :load_note_body, :ticket_cc_email_backup
  before_save :update_response_violation, on: :create, if: :update_sla_violation?
  before_save :update_note_changes
  before_save :validate_schema_less_note
  before_update :load_full_text

  before_destroy :save_deleted_note_info

  after_create :update_content_ids, :update_parent, :add_activity

  after_commit :fire_create_event, on: :create
  # Doing update note count before pushing to ticket_states queue
  # So that note count will be reflected if the rmq publish happens via ticket states queue
  after_commit ->(obj) { obj.safe_send(:update_note_count_for_reports)  }, on: :create , :if => :report_note_metrics?
  after_commit :update_ticket_states, on: :create, :unless => :send_and_set?
  after_commit :notify_ticket_monitor, on: :create

  after_commit :send_notifications, on: :create, :if => :human_note_for_ticket?
  after_commit :notifying_agents, on: :create, :if => :automated_note_for_ticket?
  after_commit :send_forward_ticket_email, on: :create, :if => :automation_fwd_email?

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.update_es_index }, on: :create, :if => :human_note_for_ticket?
  after_commit ->(obj) { obj.update_es_index }, on: :update, :if => :human_note_for_ticket?

  after_commit ->(obj) { obj.safe_send(:update_note_count_for_reports)  }, on: :destroy, :if => :report_note_metrics?

  after_commit :subscribe_event_create, on: :create, :if => :api_webhook_note_check
  after_commit :remove_es_document, on: :destroy, :if => :deleted_archive_note

  after_update ->(obj) { obj.notable.update_timestamp }, :if => :human_note_for_ticket?

  after_commit :update_sentiment, on: :create

  after_commit  :enqueue_for_NER, on: :create, :if => :validate_for_ner_api

  publishable
  # Callbacks will be executed in the order in which they have been included.
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  # For using Redis related functionalities
  include Redis::RedisKeys
  include Redis::OthersRedis

  def load_full_text
    note_body.full_text = note_body.body if note_body.body.present?
    note_body.full_text_html = note_body.body_html if note_body.body_html.present?
  end

  def remove_activity
    if outbound_email?
      unless private?
        notable.destroy_activity('activities.tickets.conversation.out_email.long', id)
      end
    elsif inbound_email?
      notable.destroy_activity('activities.tickets.conversation.in_email.long', id)
    else
      notable.destroy_activity("activities.tickets.conversation.#{Account.current.helpdesk_sources.note_activities_hash.fetch(source, "note")}.long", id)
    end
  end

  def update_sentiment
    if Account.current.customer_sentiment_enabled?
      if User.current.nil? || User.current.language.nil? || User.current.language = "en"
        is_agent_performed = notable.agent_performed?(self.user)
        if !is_agent_performed && ![Account.current.helpdesk_sources.note_source_keys_by_token["meta"]].include?(self.source)
          if [Account.current.helpdesk_sources.note_source_keys_by_token["phone"]].include?(self.source)
            schema_less_note.sentiment = 0
            schema_less_note.save
          else
            ::Notes::UpdateNotesSentimentWorker.perform_async({ :note_id => id, :ticket_id => notable.id})
          end
        end
     end
    end
  end

  def save_deleted_note_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
    @deleted_model_info[:archive] = false
    @deleted_model_info
  end

  protected

    def update_response_violation
      schema_less_note.response_violated = (notable.nr_due_by < (created_at || Time.zone.now))
      notable.nr_violated = schema_less_note.response_violated unless notable.nr_violated?
      schema_less_note
    end

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
        note_body.body_html = note_body.body_html.gsub("cid:#{content_id}", attach.inline_url) if content_id
        note_body.full_text_html = note_body.full_text_html.gsub("cid:#{content_id}", attach.inline_url) if content_id
      end

      # note_body.update_attribute(:body_html,self.note_body.body_html)
      # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
      #Helpdesk::Note.update_all("note_body.body_html= #{ActiveRecord::Base.connection.quote(body_html)}", ["id=? and account_id=?", id, account_id]) if body_html_changed?
    end

    def update_parent_sender_email
      return if incoming
      requester_emails = notable.requester.emails
      if requester_emails.length == 1 && !requester_emails.include?(notable.sender_email)
        notable.sender_email = notable.requester.email
      end
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
      notable.skip_sbrr = notable.skip_ocr_sync = true #to skip sbrr on note creation. make sure not to pass this to update_ticket_states worker
      notable.save
    end

    def send_notifications
      return if skip_notification || import_note
      if notable.customer_performed?(user)
        # Ticket re-opening, moved as an observer's default rule
        e_notification = account.email_notifications.find_by_notification_type(EmailNotification::REPLIED_BY_REQUESTER)
        if e_notification.agent_notification? && replied_by_customer?
          send_requester_replied_notification if notable.responder
          send_requester_replied_notification(true) if Account.current.shared_ownership_enabled? and notable.internal_agent
        end

        if public_note? and performed_by_client_manager?
          Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT, notable, self)
        end

        additional_emails = []
        ignore_emails = []
        send_cc_email_notification = false

        if inbound_email? && !self.private? && notable.included_in_cc?(user.email)
          send_cc_email_notification = true
          additional_emails << notable.requester.email if !notable.included_in_cc?(notable.requester.email)
          ignore_emails << user.email
        end
        handle_notification_for_agent_as_req if ( !incoming && notable.agent_as_requester?(user.id))

        if notable.cc_email.present? && user.id == notable.requester_id && !self.private?
          send_cc_email_notification = true
        end

        if send_cc_email_notification
          Helpdesk::TicketNotifier.send_later(:send_cc_email, notable, self, {:additional_emails => additional_emails,
                                                                             ignore_emails: ignore_emails}) unless notable.spam?
        end

        # Jira notes notifier was sending emails for portal added notes with no notifying emails. Added a to emails check to prevent that.
        integrations_private_note_notifications unless replied_by_customer? || to_emails.blank? || (!incoming && notable.agent_as_requester?(user.id))

      else
        #notify the agents only for notes
        notifying_agents
        #notify the customer if it is public note
        if note? && !self.private?
          e_notification = account.email_notifications.find_by_notification_type(EmailNotification::COMMENTED_BY_AGENT)
          Helpdesk::TicketNotifier.send_later(:notify_by_email, EmailNotification::COMMENTED_BY_AGENT, notable, self) if e_notification.requester_notification?
          if notable.cc_email.present?
            e_cc_notification = account.email_notifications.find_by_notification_type(EmailNotification::PUBLIC_NOTE_CC)
            Helpdesk::TicketNotifier.send_later(:send_cc_email, notable , self, {}) if e_cc_notification.requester_notification? and !notable.spam?
          end
        #handle the email conversion either fwd email or reply
        elsif email_conversation?
          send_reply_email
          create_fwd_note_activity(self.to_emails) if fwd_email?
        end
        # notable.responder ||= self.user unless private_note? # Added as a default observer rule
      end
    end

    def integrations_private_note_notifications(internal_notification = false)
      Helpdesk::TicketNotifier.send_later(:notify_by_email, (EmailNotification::NOTIFY_COMMENT),
              notable, self, {:internal_notification => internal_notification})
    end

    def send_requester_replied_notification(internal_notification = false)
      # if the source is "feedback" then send the notification email after 2 minutes
      send_at = ([Account.current.helpdesk_sources.note_source_keys_by_token["feedback"]].include?(self.source))? 2 : 0
      args = [(EmailNotification::REPLIED_BY_REQUESTER), notable, self, {:internal_notification => internal_notification}]
      Delayed::Job.enqueue(Delayed::PerformableMethod.new(Helpdesk::TicketNotifier, :notify_by_email, args), nil, send_at.minutes.from_now)
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
      send_forward_ticket_email(true) if fwd_email?
    end

    def notifying_agents
      if (note? || automated_note_for_ticket?) && !self.to_emails.blank? && !incoming
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
        notable.create_activity(user, "activities.tickets.conversation.#{Account.current.helpdesk_sources.note_activities_hash.fetch(source, "note")}.long",
          {'eval_args' => {"#{Account.current.helpdesk_sources.note_activities_hash.fetch(source, "comment")}_path" => ["#{Account.current.helpdesk_sources.note_activities_hash.fetch(source, "comment")}_path",
                                {'ticket_id' => notable.display_id, 'comment_id' => id}]}},
          "activities.tickets.conversation.#{Account.current.helpdesk_sources.note_activities_hash.fetch(source, "note")}.short")
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

    def update_note_changes
      @model_changes = self.changes.to_hash unless defined?(@model_changes)
      RELATED_ASSOCIATIONS.each do |association|
        @model_changes.merge!(self.send(association).changes.try(:to_hash))
      end
      @model_changes.symbolize_keys!
    end

    def reset_emails(emails_array)
      emails_array.map{|emails| fetch_valid_emails(emails)}
    end

    def update_ticket_states
      return if meta? || import_note
      user_id = User.current.id if User.current
      unless zendesk_import?
        args = {
          id: id,
          model_changes: @model_changes,
          freshdesk_webhook: freshdesk_webhook?,
          current_user_id: user_id
        }
        job_id = ::Tickets::UpdateTicketStatesWorker.perform_async(args)
        Va::Logger::Automation.set_thread_variables(account_id, notable_id, user_id)
        Va::Logger::Automation.log("Triggering UpdateTicketStatesWorker, job_id=#{job_id}, info=#{args.inspect}", true)
        Va::Logger::Automation.unset_thread_variables
      end
    end

    def notify_ticket_monitor
      return if meta? || import_note
      notable.subscriptions.each do |subscription|
        if subscription.user_id != user_id
          Helpdesk::WatcherNotifier.send_later(:deliver_notify_on_reply, notable, subscription, self, locale_object: subscription.user)
        end
      end
    end

    def ticket_cc_email_backup
      @prev_cc_email = notable.cc_email.dup unless notable.cc_email.blank?
    end

    # VA - Observer Rule
    def update_observer_events
      return if user.nil? || !human_note_for_ticket? || feedback? ||
               !(notable.instance_of? Helpdesk::Ticket) || broadcast_note? ||
                disable_observer_rule || summary_note?
      if replied_by_customer? || replied_by_agent?
        @model_changes = {:reply_sent => :sent}
      else
        @model_changes = {:note_type => NOTE_TYPE[private]}
      end
    end

    def send_and_set?
      unless self.changes_for_observer.nil?
        self.changes_for_observer = @model_changes
        user_id = User.current.id if User.current
        return true
      end
      return false
    end

    def replied_by_customer?
      # Added the private note check when agent as a requester adds a private note should not trigger the observer rule
      # (Should behave as a private note)
      (user.customer? && (tweet? || fb_note? || !private?)) || (notable.agent_as_requester?(user.id) && (public_note? || email?))
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
        if (notable.created_at < ('1-10-2015'.to_datetime) && notable.schema_less_ticket.reports_hash["recalculated_count"].nil?)
          notable.schema_less_ticket.safe_send("recalculate_note_count")
        else
          notable.schema_less_ticket.safe_send("update_#{note_category}_count", action)
        end
        Rails.logger.info "Helpdesk::Note::update_note_count_for_reports::#{Time.zone.now.to_f} and schema_less_ticket_object :: #{notable.schema_less_ticket.reports_hash.inspect}"
        notable.schema_less_ticket.save
      end
    end

    # This can be put in a separate module and can be included wherever needed.
    # This remains common for all active record transactions
    def model_transaction_action
      if self.safe_send(:transaction_include_action?, :create)
        action = "create"
      elsif self.safe_send(:transaction_include_action?, :update)
        action = "update"
      elsif self.safe_send(:transaction_include_action?, :destroy)
        action = "destroy"
      end
    end

    def reports_note_category
      case schema_less_note.category
      when CATEGORIES[:customer_response]
        "customer_reply"
      # Only agent added pvt notes, fwds and reply to fwd will be counted as pvt note
      when CATEGORIES[:agent_private_response], CATEGORIES[:reply_to_forward], CATEGORIES[:broadcast]
        "private_note"
      when CATEGORIES[:agent_public_response]
        (note? ? "public_note" : "agent_reply")
      else
        Rails.logger.debug "Undefined note category #{schema_less_note.category}"
      end
    end

    def report_note_metrics?
      human_note_for_ticket? && !feedback? && !summary_note?
    end
    ######## ****** Methods related to reports ends here ******** #####


    # preventing deletion from elastic search
    def deleted_archive_note
      if Account.current.features_included?(:archive_tickets) && self.notable && self.notable.archive
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

    def create_broadcast_message
      params = {
        :tracker_display_id => notable.display_id,
        :body => note_body.body,
        :body_html => note_body.body_html
      }
      build_broadcast_message(params)
    end

    def validate_for_ner_api
      self.account.falcon_enabled? && self.incoming? && self.user.customer? && google_calendar_enabled?
    end

    def google_calendar_enabled?
      self.account.installed_applications.with_name("google_calendar").present?
    end

    # Trigger background job for NER API on creation of incoming notes

    def enqueue_for_NER
      NERWorker.perform_async({:obj_id => self.id, :obj_type => :notes,
        :text => self.body, :html => self.body_html}) if ((self.user.language == 'en') && account.launched?(:ner))
    end

    def send_forward_ticket_email(create_activity = false)
      return if import_note
      Helpdesk::TicketNotifier.send_later(:deliver_forward, notable, self) unless only_kbase?
      create_fwd_note_activity(self.to_emails) if create_activity
    end

    def update_sla_violation?
      Account.current.next_response_sla_enabled? && notable.nr_due_by.present? && !private? && notable.agent_performed?(user) && !notable.outbound_email?
    end
end
