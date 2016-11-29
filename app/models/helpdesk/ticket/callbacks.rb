class Helpdesk::Ticket < ActiveRecord::Base

  # rate_limit :rules => lambda{ |obj| Account.current.account_additional_settings_from_cache.resource_rlimit_conf['helpdesk_tickets'] }, :if => lambda{|obj| obj.rl_enabled? }

	before_validation :populate_requester, :load_ticket_status, :set_default_values
  before_validation :assign_flexifield, :assign_email_config_and_product, :on => :create
  before_validation :validate_assoc_parent_ticket, :on => :create, :if => :child_ticket?
  before_validation :validate_related_tickets, :on => :create, :if => :tracker_ticket?
  before_validation :validate_tracker_ticket, :on => :update, :if => :tracker_ticket_id

  before_create :set_outbound_default_values, :if => :outbound_email?

  before_create :assign_schema_less_attributes, :save_ticket_states, :add_created_by_meta, :build_reports_hash

  before_create :assign_display_id, :if => :set_display_id?

  before_create :set_company_id

  before_create :set_boolean_custom_fields

	before_update :assign_email_config

  before_update :update_message_id, :if => :deleted_changed?

  before_save  :assign_outbound_agent,  :if => :new_outbound_email?

  before_save :reset_internal_group_agent

  before_save  :update_ticket_related_changes, :update_company_id, :set_sla_policy

  before_save :check_and_reset_company_id, :if => :company_id_changed?

  before_update :update_sender_email

  before_update :stop_recording_timestamps, :unless => :model_changes?

  before_update :round_robin_on_ticket_update, :unless => :skip_rr_on_update?

  before_update :reset_assoc_tkts, :if => :remove_associations?

  before_update :reset_assoc_parent_tkt_status, :if => :assoc_parent_ticket?

  after_update :start_recording_timestamps, :unless => :model_changes?

  before_save :update_dueby, :unless => :manual_sla?


  before_update :update_isescalated, :if => :check_due_by_change
  before_update :update_fr_escalated, :if => :check_frdue_by_change

  after_create :refresh_display_id, :create_meta_note, :update_content_ids
  after_create :set_parent_child_assn, :if => :child_ticket?
  after_save :check_child_tkt_status, :if => :child_ticket?

  after_commit :create_initial_activity, :pass_thro_biz_rules, on: :create
  after_commit :send_outbound_email, :update_capping_on_create, on: :create, :if => :outbound_email?

  after_commit :filter_observer_events, on: :update, :if => :execute_observer?
  after_commit :update_ticket_states, :notify_on_update, :update_activity,
               :stop_timesheet_timers, :fire_update_event, :push_update_notification,
               :update_old_group_capping, on: :update
  #after_commit :regenerate_reports_data, on: :update, :if => :regenerate_data?
  after_commit :push_create_notification, on: :create
  after_commit :update_group_escalation, on: :create, :if => :model_changes?
  after_commit :publish_to_update_channel, on: :update, :if => :model_changes?
  after_commit :subscribe_event_create, on: :create, :if => :allow_api_webhook?, :unless => :spam_or_deleted?
  after_commit :subscribe_event_update, on: :update, :if => :allow_api_webhook?, :unless => :spam_or_deleted?
  after_commit :set_links, :on => :create, :if => :tracker_ticket?
  after_commit :add_links, :on => :update, :if => :linked_now?
  after_commit :remove_links, :on => :update, :if => :unlinked_now?
  after_commit :save_sentiment, on: :create 
  
  # Callbacks will be executed in the order in which they have been included. 

  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher


  def set_outbound_default_values
    if email_config
      self.to_emails = [email_config.reply_email]
      self.to_email = email_config.reply_email
    end
  end

  def assign_outbound_agent
    return if responder_id
     if User.current.try(:id) and User.current.agent?
      self.responder_id = User.current.id
    end
  end

  def construct_ticket_old_body_hash
    {
      :description => self.ticket_body_content.description,
      :description_html => self.ticket_body_content.description_html,
      :raw_text => self.ticket_body_content.raw_text,
      :raw_html => self.ticket_body_content.raw_html,
      :meta_info => self.ticket_body_content.meta_info,
      :version => self.ticket_body_content.version,
      :account_id => self.account_id,
      :ticket_id => self.id
    }
  end

  def set_default_values
    self.source       = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if self.source == 0
    self.ticket_type  = nil if self.ticket_type.blank?

    self.subject    ||= ''
    self.group_id   ||= email_config.try(:group_id)
    self.priority   ||= PRIORITY_KEYS_BY_TOKEN[:low]
    self.created_at ||= Time.now.in_time_zone(account.time_zone)

    build_ticket_body(:description_html => self.description_html,
      :description => self.description) unless ticket_body
  end

  def save_ticket_states
    self.ticket_states                = self.ticket_states || Helpdesk::TicketState.new
    ticket_states.tickets             = self
    ticket_states.created_at          = ticket_states.created_at || created_at
    ticket_states.account_id          = account_id
    ticket_states.assigned_at         = ticket_states.first_assigned_at = time_zone_now if responder_id
    ticket_states.pending_since       = Time.zone.now if (status == PENDING)

    ticket_states.set_resolved_at_state(created_at) if ((status == RESOLVED) and ticket_states.resolved_at.nil?)
    ticket_states.resolved_at ||= ticket_states.set_closed_at_state(created_at) if (status == CLOSED)

    ticket_states.status_updated_at    = created_at || time_zone_now
    ticket_states.sla_timer_stopped_at = time_zone_now if (ticket_status.stop_sla_timer?)
    #Setting inbound as 0 and outbound as 1 for outbound emails as its agent initiated
    if outbound_email?
      ticket_states.inbound_count = 0
      ticket_states.outbound_count = 1
    end
  end

  def update_sender_email
    assign_sender_email

    # save only if there are any changes. unnecessary transaction is avoided.
    schema_less_ticket.save if schema_less_ticket.changed?
  end

  def update_ticket_states
    process_agent_and_group_changes
    process_status_changes
    ticket_states.save if ticket_states.changed?
    schema_less_ticket.save
  end

  def save_sentiment
    if Account.current.customer_sentiment_enabled?
     if User.current.nil? || User.current.language.nil? || User.current.language = "en"
       if [SOURCE_KEYS_BY_TOKEN[:chat],SOURCE_KEYS_BY_TOKEN[:phone]].include?(self.source)
         schema_less_ticket.sentiment = 0
         schema_less_ticket.save
       else
          ::Tickets::UpdateSentimentWorker.perform_async( { :id => id } )
       end
     end
    end
  end

  def process_agent_and_group_changes
    if (@model_changes.key?(:responder_id) && responder)
      if @model_changes[:responder_id][0].nil?
        unless ticket_states.first_assigned_at
          ticket_states.first_assigned_at = time_zone_now
          schema_less_ticket.set_first_assign_bhrs(self.created_at, ticket_states.first_assigned_at, self.group)
        end
      else
        schema_less_ticket.update_agent_reassigned_count("create")
      end
      schema_less_ticket.set_agent_assigned_flag
      ticket_states.assigned_at=time_zone_now
    end

    if (@model_changes.key?(:group_id) && group)
      schema_less_ticket.update_group_reassigned_count("create") if @model_changes[:group_id][0]
      schema_less_ticket.set_group_assigned_flag
    end
    #for internal_agent_id
    if @model_changes.key?(:long_tc04)
      schema_less_ticket.set_internal_agent_assigned_flag
      schema_less_ticket.set_internal_agent_first_assign_bhrs(self.created_at, time_zone_now, self.group) if (self.reports_hash["internal_agent_assigned_flag"]==true )
    end
    schema_less_ticket.set_internal_group_assigned_flag if @model_changes.key?(:long_tc03)
  end

  def process_status_changes
    return unless @model_changes.key?(:status)

    ticket_states.status_updated_at = time_zone_now

    ticket_states.pending_since = nil if @model_changes[:status][0] == PENDING
    ticket_states.pending_since=time_zone_now if (status == PENDING)
    ticket_states.set_resolved_at_state if (status == RESOLVED)
    ticket_states.set_closed_at_state if closed?

    if(ticket_status.stop_sla_timer)
      ticket_states.sla_timer_stopped_at ||= time_zone_now
    else
      ticket_states.sla_timer_stopped_at = nil
    end

    if reopened_now?
      schema_less_ticket.set_last_resolved_at(ticket_states.resolved_at)
      ticket_states.opened_at=time_zone_now
      ticket_states.reset_tkt_states
      schema_less_ticket.update_reopened_count("create")
    end
  end

  #Shared onwership Validations
  def reset_internal_group_agent
    (schema_less_ticket.internal_agent_id = schema_less_ticket.internal_group_id = nil) or return unless Account.current.features?(:shared_ownership)
    return unless (status_changed? || shared_ownership_fields_changed?)

    #Nullify internal group when the status(without the particular group mapped) is changed.
    #If the new status has the same group mapped to it, preserve internal group and internal agent.
    if !valid_internal_group?
      previous_ig_id = internal_group_id_changed? ? internal_group_id_changes[0] : schema_less_ticket.internal_group_id
      schema_less_ticket.internal_group_id = (valid_internal_group?(previous_ig_id) ? previous_ig_id : nil)
    end

    #Nullify internal agent when the status or internal group(without the particular agent mapped) is changed.
    #If the new group has the same agent mapped to it, preserve internal agent.
    if !valid_internal_agent?
      previous_ia_id = internal_agent_id_changed? ? internal_agent_id_changes[0] : schema_less_ticket.internal_agent_id
      schema_less_ticket.internal_agent_id = (valid_internal_agent?(previous_ia_id) ? previous_ia_id : nil)
    end
  end

  #Shared onwership Validations ends here

  def refresh_display_id #by Shan temp
      self.display_id = Helpdesk::Ticket.select(:display_id).where(id: id).first.display_id  if display_id.nil? #by Shan hack need to revisit about self as well.
  end

  def create_meta_note
      # Added for storing metadata from MobiHelp
      if meta_data.present?
        meta_note = self.notes.build(
          :note_body_attributes => {:body => meta_data.map { |k, v| "#{k}: #{v}" }.join("\n")},
          :private => true,
          :notable => self,
          :user => self.requester,
          :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
          :account_id => self.account.id,
          :user_id => self.requester.id
        )
        meta_note.attachments = meta_note.inline_attachments = []
        meta_note.save_note
      end
  end

  def add_created_by_meta
    if User.current and User.current.id != requester.id and import_id.nil?
      meta_info = { "created_by" => User.current.id, "time" => time_zone_now }
      if self.meta_data.blank?
        self.meta_data = meta_info
      elsif self.meta_data.is_a?(Hash)
        self.meta_data.merge!(meta_info)
      end
    end
  end

  def pass_thro_biz_rules
    return if Account.current.skip_dispatcher?
    #Remove redis check if no issues after deployment
    if Account.current.launched?(:delayed_dispatchr_feature)
      send_later(:delayed_rule_check, User.current, freshdesk_webhook?) unless (import_id or outbound_email?)
    else
      # This queue includes dispatcher_rules, auto_reply, round_robin.
      Helpdesk::Dispatcher.enqueue(self.id, (User.current.blank? ? nil : User.current.id), freshdesk_webhook?) unless (import_id or outbound_email?)
    end
  end

  #To be removed after dispatcher redis check removed
  def delayed_rule_check current_user, freshdesk_webhook
   begin
    set_account_time_zone
    evaluate_on = check_rules(current_user) unless freshdesk_webhook
    autoreply
    assign_tickets_to_agents unless spam? || deleted?
   rescue Exception => e #better to write some rescue code
    NewRelic::Agent.notice_error(e)
   end
    save #Should move this to unless block.. by Shan
    self.va_rules_after_save_actions.each do |action|
      klass = action[:klass].constantize
      klass.send(action[:method], action[:args])
    end
  end

  #To be removed after dispatcher redis check removed
  def check_rules current_user
    evaluate_on = self
    account.va_rules.each do |vr|
      evaluate_on = vr.pass_through(self,nil,current_user)
      next if account.features?(:cascade_dispatchr)
      return evaluate_on unless evaluate_on.nil?
    end
    return evaluate_on
  end

  def stop_timesheet_timers
    if @model_changes.key?(:status) && [RESOLVED, CLOSED].include?(status)
       running_timesheets =  time_sheets.find(:all , :conditions =>{:timer_running => true})
       running_timesheets.each{|timer|
        timer.stop_timer
        Integrations::TimeSheetsSync.update(timer, User.current)
       }
    end
   end

  def update_message_id
    (self.header_info[:message_ids] || []).each do |parent_message|
      message_key = EMAIL_TICKET_ID % {:account_id => self.account_id, :message_id => parent_message}
      deleted ? remove_others_redis_key(message_key) : set_others_redis_key(message_key,
                                                                            "#{self.display_id}:#{parent_message}",
                                                                            86400*7)
    end
  end


  #SLA Related changes..

  def set_sla_policy
    return if !(changed_condition? || self.sla_policy.nil?)
    new_match = nil
    account.sla_policies.rule_based.active.each do |sp|
      if sp.matches? self
        new_match = sp
        break
      end
    end

    self.sla_policy = (new_match || account.sla_policies.default.first)
    self
  end

  def changed_condition?
    group_id_changed? || source_changed? || has_product_changed? || ticket_type_changed? || company_id_changed?
  end

  def has_product_changed?
    self.schema_less_ticket.changes.key?('product_id')
  end

  def update_dueby(ticket_status_changed=false)
    Rails.logger.info "Created at::: #{self.created_at}"
    BusinessCalendar.execute(self) { set_sla_time(ticket_status_changed) }
    #Hack - trying to recalculte again if it gives a wrong value on ticket creation.
    if self.new_record? and ((due_by < created_at) || (frDueBy < created_at))
      old_time_zone = Time.zone
      TimeZone.set_time_zone
      NewRelic::Agent.notice_error(Exception.new("Wrong SLA calculation:: Account::: #{account.id}, Old timezone ==> #{old_time_zone}, Now ===> #{Time.zone}"))
      BusinessCalendar.execute(self) { set_sla_time(ticket_status_changed) }
    end
  end

  #shihab-- date format may need to handle later. methode will set both due_by and first_resp
  def set_sla_time(ticket_status_changed)
    if self.new_record? || priority_changed? || changed_condition? || status_changed? || ticket_status_changed
      sla_detail = self.sla_policy.sla_details.where(priority: priority).first
      set_dueby_on_priority_change(sla_detail) if (self.new_record? || priority_changed? || changed_condition?)
      set_dueby_on_status_change(sla_detail) if !self.new_record? && (status_changed? || ticket_status_changed)
      Rails.logger.debug "sla_detail_id :: #{sla_detail.id} :: due_by::#{self.due_by} and fr_due:: #{self.frDueBy} "
    end
  end

  #end of SLA

  def set_account_time_zone
    self.account.make_current
    Time.zone = self.account.time_zone
  end

  def set_user_time_zone
    begin
      Time.zone = User.current.time_zone
    rescue ArgumentError => e
      Rails.logger.info  "User timezone is invalid:: userid:: #{User.current.id}, Timezone :: #{User.current.time_zone}"
      set_account_time_zone
    end
  end

  def set_display_id?
    display_id.nil? && Account.current.features?(:redis_display_id)
  end

  def assign_display_id
    #not taking care of decrementing the counter on rollback

    key      = TICKET_DISPLAY_ID % { :account_id => account_id }
    lock_key = DISPLAY_ID_LOCK % { :account_id => account_id }

    TicketConstants::TICKET_DISPLAY_ID_MAX_LOOP.times do
      computed_display_id = increment_display_id_redis_key(key).to_i
      #computed_display_id will be 0 if the redis command fails,
      #in which case we will keep retrying till we timeout

      #normal workflow
      if computed_display_id > 1
        self.display_id = computed_display_id.to_i
        return
      #first time, when the key is a huge -ve value
      elsif computed_display_id < 0
        if set_display_id_redis_with_expiry(lock_key, 1, { :ex => TicketConstants::TICKET_ID_LOCK_EXPIRY,
                                                       :nx => true })
          computed_display_id = account.get_max_display_id
          set_display_id_redis_key(key, computed_display_id)
          self.display_id = computed_display_id
          return
        end
      end
    end
    account.features.redis_display_id.destroy

    notification_topic = SNS["dev_ops_notification_topic"]
    options = { :account_id => account_id, :environment => Rails.env }
    DevNotification.publish(notification_topic, "Redis Display ID - Retry limit exceeded", options.to_json)

    Rails.logger.debug "Redis Display ID - Retry limit exceeded in #{account_id}"
    NewRelic::Agent.notice_error("Redis Display ID - Retry limit exceeded in #{account_id}")
  end

  # Linked ticket validations...
  def validate_related_tickets
    if related_ticket_ids.count == 1
      @related_ticket = Account.current.tickets.permissible(User.current).readonly(false).find_by_display_id(related_ticket_ids)
      unless(@related_ticket && @related_ticket.association_type.nil? && @related_ticket.can_be_associated? )
        errors.add(:base,t("ticket.link_tracker.permission_denied")) and return false
      end
    elsif links_limit_exceeded(related_ticket_ids.count)
      errors.add(:base,t("ticket.link_tracker.count_exceeded", :count => TicketConstants::MAX_RELATED_TICKETS)) and return false
    end
  end

  def validate_tracker_ticket
    @tracker_ticket = Account.current.tickets.find_by_display_id(tracker_ticket_id)
    unless @tracker_ticket && @tracker_ticket.tracker_ticket? && !@tracker_ticket.spam_or_deleted? && self.can_be_associated?
      errors.add(:base,t("ticket.link_tracker.permission_denied")) and return false
    end
    if self.association_type && @tracker_ticket.associates.present? && links_limit_exceeded(@tracker_ticket.associates.count + 1)
      errors.add(:base,t("ticket.link_tracker.count_exceeded",:count => TicketConstants::MAX_RELATED_TICKETS)) and return false
    end
    self.associates_rdb = related_ticket? ? @tracker_ticket.display_id : nil
  end

  def set_links
    Rails.logger.debug "Linking Related tickets [#{related_ticket_ids}] to tracker_ticket #{self.display_id}"
    if @related_ticket.present? && set_tkt_assn_type(@related_ticket, :related)
      self.associates = [ @related_ticket.display_id ]
    elsif related_ticket_ids.count > 1
      ::Tickets::LinkTickets.perform_async({:tracker_id => self.display_id, :related_ticket_ids => related_ticket_ids})
    end
  end

  def linked_now?
    tracker_ticket_id && related_ticket? && @model_changes.key?(Helpdesk::SchemaLessTicket.association_type_column) &&
      @model_changes[Helpdesk::SchemaLessTicket.association_type_column][0].nil?
  end

  def unlinked_now?
    tracker_ticket_id && !related_ticket? && @model_changes.key?(Helpdesk::SchemaLessTicket.association_type_column) &&
      @model_changes[Helpdesk::SchemaLessTicket.association_type_column][0] == TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]
  end

  def add_links
    Rails.logger.debug "Linking Related tickets [#{self.id}] to tracker_ticket #{@tracker_ticket.display_id}"
    @tracker_ticket.add_associates([self.display_id])
    create_tracker_activity(:tracker_link)
    self.associates = [ @tracker_ticket.display_id ]
  end

  def remove_links
    Rails.logger.debug "Uninking Related tickets [#{self.id}] from tracker_ticket #{@tracker_ticket.display_id}"
    self.remove_all_associates
    @tracker_ticket.remove_associates([self.display_id])
    create_tracker_activity(:tracker_unlink)
  end

  # Parent Child ticket validations...
  def validate_assoc_parent_ticket
    @assoc_parent_ticket = Account.current.tickets.permissible(User.current).readonly(false).find_by_display_id(assoc_parent_tkt_id)
    if !(@assoc_parent_ticket && @assoc_parent_ticket.can_be_associated?)
      errors.add(:base,t("ticket.parent_child.permission_denied")) and return false
    elsif !@assoc_parent_ticket.child_tkt_limit_reached?
      errors.add(:base,t("ticket.parent_child.count_exceeded",:count => TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT)) and return false
    end
    self.associates_rdb = @assoc_parent_ticket.display_id
  end

  def set_parent_child_assn
    Rails.logger.debug "Creating child ticket #{self.display_id} for the assoc_parent_ticket #{assoc_parent_tkt_id}"
    if @assoc_parent_ticket && update_assoc_parent_tkt
      self.associates = [@assoc_parent_ticket.display_id]
    end
  end

  #reset associated parent tkt status if any of the child is not resolved/closed
  def reset_assoc_parent_tkt_status
    if status_changed_now? and self.validate_assoc_parent_tkt_status
      self.status = @model_changes[:status][0]
      # scenario automation
      action_log = Thread.current[:scenario_action_log]
      Thread.current[:scenario_action_log][:status] = I18n.t('ticket.unresolved_child') if action_log.present? and action_log[:status].present?
      # for activities
      self.system_changes.each do |key, value|
        value.delete(:status) if value[:status].present?
      end if system_changes.present?
    end
  end

  def check_child_tkt_status
    if status_changed? and ![RESOLVED, CLOSED].include?(status)
      assoc_parent_ticket = @assoc_parent_ticket ? @assoc_parent_ticket : self.associated_prime_ticket("child")
      if [RESOLVED, CLOSED].include?(assoc_parent_ticket.status)
        assoc_parent_ticket.update_attributes(:status => OPEN)
      end
    end
  end

  def status_changed_now?
    status_changed? && !previous_state_was_resolved_or_closed? && changed_to_closed_or_resolved?
  end

  def reset_assoc_tkts
    ::Tickets::ResetAssociations.perform_async({:ticket_ids=>[self.display_id]})
  end

private

  def push_create_notification
	push_mobile_notification(:new)
  end

  def push_update_notification
    if @model_changes.key?(:responder_id)
      return unless send_agent_assigned_notification?
    end
    push_mobile_notification(:update) unless spam? || deleted?
  end

  def push_mobile_notification(type)
	return unless @model_changes.key?(:responder_id) || @model_changes.key?(:group_id) || @model_changes.key?(:status)

    message = {
                :ticket_id => display_id,
                :group => group_name,
                :status_name => status_name,
                :requester => requester_name,
                :subject => truncate(subject, :length => 100),
                :priority => priority,
                :time => updated_at.to_i
              }
	send_mobile_notification(type,message)
  end

  def model_changes?
    @model_changes.present?
  end

  def auto_refresh_allowed?
    Account.current.features?(:auto_refresh)
  end

  #RAILS3 Hack. TODO - @model_changes is a HashWithIndifferentAccess so we dont need symbolize_keys!,
  #but observer excpects all keys to be symbols and not strings. So doing a workaround now.
  #After Rails3, we will cleanup this part
  # TODO - Must change in new reports when this method is changed.
  def update_ticket_related_changes
    @model_changes = self.changes.to_hash
    @model_changes.merge!(:round_robin_assignment => [nil, true]) if round_robin_assignment
    @model_changes.merge!(schema_less_ticket.changes) unless schema_less_ticket.nil?
    @model_changes.merge!(flexifield.changes) unless flexifield.nil?
    @model_changes.merge!({ tags: [] }) if self.tags_updated #=> Hack for when only tags are updated to trigger ES publish
    @model_changes.symbolize_keys!
  end

  def load_ticket_status
    ticket_statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current)
    self[:status] ||= OPEN
    ticket_status = ticket_statuses.find {|x| x.status_id == status }
    self.ticket_status = !ticket_status || ticket_status.deleted? ? ticket_statuses.find { |x| x.status_id == OPEN } : ticket_status
  end

  def set_company_id
    if self.source == 1 && self.requester.contractor? && self.from_email != self.requester.email
      domain = (/@(.+)/).match(self.from_email).to_a[1]
      comp_domain = account.company_domains.where("domain = '#{domain}'").first
      self.owner_id = comp_domain.company_id if comp_domain && requester.company_ids.include?(comp_domain.company_id)
    end
  end

  def set_boolean_custom_fields
    Account.current.ticket_field_def.boolean_ff_aliases.each do |f|
      set_ff_value(f, 0) unless self.send(f)
    end
  end

  def update_company_id
    # owner_id will be used as an alias attribute to refer to a ticket's company_id
    self.owner_id = self.requester.company_id if @model_changes.key?(:requester_id) &&
                                                 (self.owner_id.nil? ||
                                                  self.requester.company_ids.length < 2)
  end

  def check_and_reset_company_id
    self.owner_id = owner_id_was if self.owner_id.present? &&
                                    !requester.company_ids.include?(self.owner_id)
  end

  def populate_requester
    return if requester
    self.requester_id = nil
    unless email.blank?
      name_email = parse_email email  #changed parse_email to return a hash
      self.email = name_email[:email]
      self.name ||= name_email[:name]
      @requester_name ||= self.name # for MobiHelp
    end

    assign_agent_requester if tracker_ticket?

    self.requester ||= account.all_users.find_by_an_unique_id({
      :email => self.email,
      :twitter_id => twitter_id,
      :external_id => external_id,
      :fb_profile_id => facebook_id,
      :phone => phone,
      :unqiue_external_id => unique_external_id })

    create_requester unless requester
  end

  def assign_agent_requester
    agent_requester = account.technicians.find_by_email(email)
    if agent_requester.present?
      self.requester = agent_requester
    else
      errors.add(:base,t("ticket.tracker_agent_error"))
    end
  end

  def create_requester
    if can_add_requester?
      portal = self.product.try(:portal)
      language = portal.language if (portal and self.source!=SOURCE_KEYS_BY_TOKEN[:email]) #Assign languages only for non-email tickets
      requester = account.users.new
      requester.account = account
      requester.signup!({:user => {
        :email => self.email, #user_email changed
        :twitter_id => twitter_id, :external_id => external_id,
        :name => name || twitter_id || @requester_name || external_id || unique_external_id,
        :helpdesk_agent => false, :active => email.blank?,
        :phone => phone, :language => language, :unqiue_external_id => unique_external_id
        }},
        portal, !outbound_email?) # check @requester_name and active

      self.requester = requester
    end
  end

  def can_add_requester?
    email.present? || twitter_id.present? || external_id.present? || phone.present? || unique_external_id.present?
  end

  def update_content_ids
    header = self.header_info
    return if inline_attachments.empty? or header.nil? or header[:content_ids].blank?

    description_updated = false
    inline_attachments.each_with_index do |attach, index|
      content_id = header[:content_ids][attach.content_file_name+"#{index}"]
      self.ticket_body.description_html = self.ticket_body.description_html.sub("cid:#{content_id}", attach.content.url) if content_id
    end
    # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
    #Helpdesk::Ticket.update_all("description_html= #{ActiveRecord::Base.connection.quote(description_html)}", ["id=? and account_id=?", id, account_id]) \
       # if description_updated
  end

  def assign_schema_less_attributes
    build_schema_less_ticket unless schema_less_ticket
    schema_less_ticket.account_id ||= account_id
    assign_sender_email
  end

  def assign_sender_email
    self.sender_email = self.email if self.email && self.email =~ EMAIL_REGEX
  end

  def assign_email_config_and_product
    if email_config
      self.product_id = email_config.product_id
    elsif self.product
      self.email_config = self.product.primary_email_config
    end
    self.group_id ||= email_config.try(:group_id)
  end

  def assign_email_config
    assign_schema_less_attributes unless schema_less_ticket
    if schema_less_ticket.changed.include?("product_id")
      if self.product
        self.email_config = self.product.primary_email_config if email_config.nil? || (email_config.product.nil? || (email_config.product.id != self.product.id))
      else
        self.email_config = nil
      end
    end
    schema_less_ticket.save unless schema_less_ticket.changed.empty?
  end

  def set_token
    self.access_token ||= generate_token
  end

  def generate_token
    public_ticket_token = Account.current.public_ticket_token
    if public_ticket_token.present?
      # using OpenSSL::HMAC.hexdigest for a 64 char hash
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), public_ticket_token, '%s/%s' % [Account.current.id, self.id])
    else
      # using Digest::SHA2.hexdigest for a 64 char hash
      # using ticket id, current account id along with Time.now
      Digest::SHA2.hexdigest("#{Account.current.id}:#{self.id}:#{Time.now.to_f}")
    end
  end

  def fire_update_event
    fire_event(:update, @model_changes) unless disable_observer
  end

  def publish_to_update_channel
    return unless Account.current.features?(:agent_collision)
    agent_name = User.current ? User.current.name : ""
    message = HELPDESK_TICKET_UPDATED_NODE_MSG % {:account_id => self.account_id,
                                                  :ticket_id => self.id,
                                                  :agent_name => agent_name,
                                                  :type => "updated"}
    publish_to_tickets_channel("tickets:#{self.account.id}:#{self.id}", message)
  end

  def set_dueby_on_priority_change(sla_detail)
    created_time = self.created_at.in_time_zone(Time.zone.name) || time_zone_now
    business_calendar = Group.default_business_calendar(group)
    self.due_by = sla_detail.calculate_due_by_time_on_priority_change(created_time, business_calendar)
    self.frDueBy = sla_detail.calculate_frDue_by_time_on_priority_change(created_time, business_calendar)
  end

  def set_dueby_on_status_change(sla_detail)
    if calculate_dueby_and_frdueby?
      business_calendar = Group.default_business_calendar(group)
      self.due_by = sla_detail.calculate_due_by_time_on_status_change(self,business_calendar)
      self.frDueBy = sla_detail.calculate_frDue_by_time_on_status_change(self,business_calendar)
      if changed_to_closed_or_resolved?
        update_ticket_state_sla_timer
      end
    end
  end

  def calculate_dueby_and_frdueby?
    changed_to_sla_timer_calculated_status? || changed_from_sla_timer_stopped_status_to_closed_or_resolved?
  end

  def changed_to_sla_timer_calculated_status?
    !(ticket_status.stop_sla_timer or ticket_states.sla_timer_stopped_at.nil?)
  end

  def changed_from_sla_timer_stopped_status_to_closed_or_resolved?
    changed_to_closed_or_resolved? && previous_state_was_sla_stop_state? && !previous_state_was_resolved_or_closed?
  end

  def changed_to_closed_or_resolved?
    [CLOSED, RESOLVED].include?(ticket_status.status_id)
  end

  def previous_state_was_resolved_or_closed?
    [RESOLVED,CLOSED].include?(@model_changes[:status][0])
  end

  def previous_state_was_sla_stop_state?
    Helpdesk::TicketStatus.status_objects_from_cache(account).find {|x| x.status_id == @model_changes[:status][0] }.stop_sla_timer?
  end

  def update_ticket_state_sla_timer
    ticket_states.sla_timer_stopped_at = time_zone_now
    ticket_states.save
  end

  def regenerate_reports_data
    set_reports_redis_key(account_id, created_at)
    set_reports_redis_key(account_id, self.ticket_states.resolved_at) if is_resolved_or_closed?
  end

  def is_resolved_or_closed?
    [RESOLVED,CLOSED].include?(self.status) && self.ticket_states.resolved_at
  end

  def regenerate_data?
    (@model_changes.keys & report_regenerate_fields).any? && (created_at.strftime("%Y-%m-%d") != updated_at.strftime("%Y-%m-%d"))
  end

  def report_regenerate_fields
    regenerate_fields = [:deleted, :spam,:responder_id]
    if Account.current.features?(:report_field_regenerate)
      regenerate_fields.concat([:source, :ticket_type, :group_id, :priority])
      #account.event_flexifields_with_ticket_fields_from_cache.each {|tkt_field| regenerate_fields.push(tkt_field[:flexifield_name].to_sym)}
    end
    regenerate_fields
  end

  def manual_sla?
    self.manual_dueby && self.due_by && self.frDueBy
  end

  def assign_flexifield
    build_flexifield
    self.flexifield_def = Account.current.ticket_field_def
    assign_ff_values custom_field
    @custom_field = nil
  end

  def update_group_escalation
    if @model_changes.key?(:group_id)
      ticket_states.group_escalated = false
      ticket_states.save if ticket_states.changed?
    end
  end

  def build_reports_hash
    current_action_time = created_at || time_zone_now
    if responder_id
      schema_less_ticket.set_first_assign_bhrs(current_action_time, ticket_states.first_assigned_at, self.group)
      schema_less_ticket.set_agent_assigned_flag
    end
    schema_less_ticket.set_group_assigned_flag if group_id
  end

  def time_zone_now
    @time_zone_now ||= Time.zone.now
  end

  def stop_recording_timestamps
    self.record_timestamps = false
    true
  end

  def start_recording_timestamps
    self.record_timestamps = true
    true
  end

  def execute_observer?
    user_present? and !disable_observer_rule
  end

  def update_assoc_parent_tkt
    is_inactive = [RESOLVED, CLOSED].include?(@assoc_parent_ticket.status)
    if @assoc_parent_ticket.assoc_parent_ticket?
      @assoc_parent_ticket.add_associates([self.display_id])
      is_inactive ? @assoc_parent_ticket.update_attributes(:status => OPEN) : true
    else
      set_tkt_assn_type(@assoc_parent_ticket, :assoc_parent, is_inactive)
    end
  end

  def set_tkt_assn_type item, value, set_status_open = false
    item.associates = [self.display_id]
    update_hash = { :association_type => TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[value] }
    if value == :related
      update_hash.merge!(:associates_rdb => self.display_id)
    elsif value == :assoc_parent and set_status_open
      update_hash.merge!(:status => OPEN)
    end
    item.update_attributes(update_hash)
  end

  def links_limit_exceeded(tickets_count)
    tickets_count > TicketConstants::MAX_RELATED_TICKETS
  end

  def remove_associations?
    deleted_or_spammed_now? && (assoc_parent_child_ticket? || linked_ticket?)
  end

  def deleted_or_spammed_now?
    (deleted_changed? && @model_changes[:deleted][0] == false) or
      (spam_changed? && @model_changes[:spam][0] == false)
  end

  def create_tracker_activity(action, tracker = @tracker_ticket)
    if Account.current.features?(:activity_revamp)
      tracker.misc_changes = {action => [self.display_id]}
      tracker.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_ACTIVITIES_TICKET_KEY)
    end
  end

  def new_outbound_email?
    outbound_email? && new_record?
  end

  def check_due_by_change
    due_by_changed? and self.due_by > time_zone_now and self.isescalated
  end

  def update_isescalated
    self.isescalated = false
    self.escalation_level = nil
    true
  end

  def check_frdue_by_change
    frDueBy_changed? and self.frDueBy > time_zone_now and
    self.fr_escalated and first_response_time.nil?
  end

  def update_fr_escalated
    self.fr_escalated = false
    true
  end
end
