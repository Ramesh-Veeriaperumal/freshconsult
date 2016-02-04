class Helpdesk::Ticket < ActiveRecord::Base

  # rate_limit :rules => lambda{ |obj| Account.current.account_additional_settings_from_cache.resource_rlimit_conf['helpdesk_tickets'] }, :if => lambda{|obj| obj.rl_enabled? }

	before_validation :populate_requester, :set_default_values
  before_validation :assign_flexifield, :on => :create

  before_create :set_outbound_default_values, :if => :outbound_email?

  before_create :assign_schema_less_attributes, :assign_email_config_and_product, :save_ticket_states, :add_created_by_meta, :build_reports_hash

  before_create :assign_display_id, :if => :set_display_id?

	before_update :assign_email_config

  before_update :update_message_id, :if => :deleted_changed?

  before_save :assign_outbound_agent, :if => :outbound_email?

  before_save  :update_ticket_related_changes, :update_company_id, :set_sla_policy, :load_ticket_status

  before_update :update_sender_email

  before_update :stop_recording_timestamps, :unless => :model_changes?
  
  before_save :round_robin_on_ticket_update, :unless => :skip_rr_on_update?

  after_update :start_recording_timestamps, :unless => :model_changes?

  before_save :update_dueby, :unless => :manual_sla?

  after_create :refresh_display_id, :create_meta_note, :update_content_ids

  after_commit :create_initial_activity, :pass_thro_biz_rules, on: :create
  after_commit :send_outbound_email, on: :create, :if => :outbound_email?

  after_commit :filter_observer_events, on: :update, :if => :execute_observer?
  after_commit :update_ticket_states, :notify_on_update, :update_activity, 
  :stop_timesheet_timers, :fire_update_event, :push_update_notification, on: :update 
  after_commit :regenerate_reports_data, on: :update, :if => :regenerate_data? 
  after_commit :push_create_notification, on: :create
  after_commit :update_group_escalation, on: :create, :if => :model_changes?
  after_commit :publish_to_update_channel, on: :update, :if => :model_changes?
  after_commit :subscribe_event_create, on: :create, :if => :allow_api_webhook?
  after_commit :subscribe_event_update, on: :update, :if => :allow_api_webhook?
  
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
    self.status       = OPEN if (!Helpdesk::TicketStatus.status_names_by_key(account).key?(self.status) or ticket_status.try(:deleted?))
    self.source       = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if self.source == 0
    self.ticket_type  = nil if self.ticket_type.blank?

    self.subject    ||= ''
    self.group_id   ||= email_config.group_id unless email_config.nil?
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
    ticket_states.assigned_at         = Time.zone.now if responder_id
    ticket_states.first_assigned_at   = Time.zone.now if responder_id
    ticket_states.pending_since       = Time.zone.now if (status == PENDING)

    ticket_states.set_resolved_at_state(created_at) if ((status == RESOLVED) and ticket_states.resolved_at.nil?)
    ticket_states.resolved_at ||= ticket_states.set_closed_at_state(created_at) if (status == CLOSED)

    ticket_states.status_updated_at    = created_at || Time.zone.now
    ticket_states.sla_timer_stopped_at = Time.zone.now if (ticket_status.stop_sla_timer?)
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
    ticket_states.save
    schema_less_ticket.save
  end
  
  def process_agent_and_group_changes 
    
    if (@model_changes.key?(:responder_id) && responder)
      if @model_changes[:responder_id][0].nil?
        unless ticket_states.first_assigned_at 
          ticket_states.first_assigned_at = Time.zone.now 
          schema_less_ticket.set_first_assign_bhrs(self.created_at, ticket_states.first_assigned_at, self.group)
        end
      else
        schema_less_ticket.update_agent_reassigned_count("create")
      end
      schema_less_ticket.set_agent_assigned_flag
      ticket_states.assigned_at=Time.zone.now
    end
    
    if (@model_changes.key?(:group_id) && group)
      schema_less_ticket.update_group_reassigned_count("create") if @model_changes[:group_id][0]
      schema_less_ticket.set_group_assigned_flag
    end
    
  end
  
  def process_status_changes
    return unless @model_changes.key?(:status)
    
    ticket_states.status_updated_at = Time.zone.now
    
    ticket_states.pending_since = nil if @model_changes[:status][0] == PENDING  
    ticket_states.pending_since=Time.zone.now if (status == PENDING)
    ticket_states.set_resolved_at_state if (status == RESOLVED)
    ticket_states.set_closed_at_state if closed?
    
    if(ticket_status.stop_sla_timer)
      ticket_states.sla_timer_stopped_at ||= Time.zone.now 
    else
      ticket_states.sla_timer_stopped_at = nil
    end 
    
    if reopened_now?
      ticket_states.opened_at=Time.zone.now
      ticket_states.reset_tkt_states
      schema_less_ticket.update_reopened_count("create")
    end
  end

  def refresh_display_id #by Shan temp
      self.display_id = Helpdesk::Ticket.find_by_id(id).display_id  if display_id.nil? #by Shan hack need to revisit about self as well.
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
    if User.current and User.current.id != requester.id and import_id.blank?
      meta_info = { "created_by" => User.current.id, "time" => Time.zone.now }
      if self.meta_data.blank?
        self.meta_data = meta_info
      elsif self.meta_data.is_a?(Hash)
        self.meta_data.merge!(meta_info)
      end
    end
  end

  def pass_thro_biz_rules
    #Remove redis check if no issues after deployment
    if redis_key_exists?(DISPATCHER_SIDEKIQ_ENABLED)
      # This queue includes dispatcher_rules, auto_reply, round_robin.
      Helpdesk::Dispatcher.enqueue(self.id, User.current.id, freshdesk_webhook?) unless (import_id or outbound_email?)
    else
      send_later(:delayed_rule_check, User.current, freshdesk_webhook?) unless (import_id or outbound_email?)
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
  end

  #To be removed after dispatcher redis check removed
  def assign_tickets_to_agents
    #Ticket already has an agent assigned to it or doesn't have a group
    return if group.nil? || self.responder_id
    if group.round_robin_enabled?
      schedule_round_robin_for_agents 
      self.save
    end
  end 

  #user changes will be passed when observer worker calls the function
  def round_robin_on_ticket_update(user_changes={})
    ticket_changes = self.changes
    ticket_changes  = merge_to_observer_changes(user_changes,self.changes) if user_changes.present?
    
    #return if no change was made to the group
    return if !ticket_changes.has_key?(:group_id)
    #skip if agent is assigned in the transaction
    return if ticket_changes.has_key?(:responder_id) && self.responder_id.present?
    #skip if the existing agent also belongs to the new group
    return if self.responder_id.present? && Account.current.agent_groups.exists?(:user_id => self.responder_id, :group_id => group_id) 

    schedule_round_robin_for_agents
  end

  def rr_allowed_on_update?
    group and (group.round_robin_enabled? and Account.current.features?(:round_robin_on_update))
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
    group_id_changed? || source_changed? || has_product_changed? || ticket_type_changed?
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
      sla_detail = self.sla_policy.sla_details.find(:first, :conditions => {:priority => priority})
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
    Account.current.features?(:redis_display_id) && display_id.nil?
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

private 

  def skip_rr_on_update?
    #Option to toggle round robin off in L2 script
    return true unless rr_allowed_on_update?
    return true if Thread.current[:skip_round_robin].present?

    #Don't trigger in case this update is a user action and it will trigger observer
    return true if user_present? && !filter_observer_events(false).blank?

    #Don't trigger during an observer save, as we call RR explicitly in the worker
    return true if Thread.current[:observer_doer_id].present?

    #Trigger RR if the update is from supervisor 
    false    
  end
 
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
    @model_changes.merge!(schema_less_ticket.changes) unless schema_less_ticket.nil?
    @model_changes.merge!(flexifield.changes) unless flexifield.nil?
    @model_changes.symbolize_keys!
  end

  def load_ticket_status
    if !self.new_record? && status_changed?
      self.ticket_status = Helpdesk::TicketStatus.status_objects_from_cache(account).find {|x| x.status_id == status }
    end
  end

  def update_company_id
    # owner_id will be used as an alias attribute to refer to a ticket's company_id
    self.owner_id = self.requester.company_id if @model_changes.key?(:requester_id)
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

    self.requester = account.all_users.find_by_an_unique_id({ 
      :email => self.email, 
      :twitter_id => twitter_id,
      :external_id => external_id,
      :fb_profile_id => facebook_id,
      :phone => phone })
    
    create_requester unless requester
  end

  def create_requester
    if can_add_requester?
      portal = self.product.portal if self.product
      language = portal.language if (portal and self.source!=SOURCE_KEYS_BY_TOKEN[:email]) #Assign languages only for non-email tickets
      requester = account.users.new
      requester.account = account
      requester.signup!({:user => {
        :email => self.email, #user_email changed
        :twitter_id => twitter_id, :external_id => external_id,
        :name => name || twitter_id || @requester_name || external_id,
        :helpdesk_agent => false, :active => email.blank?,
        :phone => phone, :language => language
        }}, 
        portal, !outbound_email?) # check @requester_name and active
      
      self.requester = requester
    end
  end

  def can_add_requester?
    email.present? || twitter_id.present? || external_id.present? || phone.present?
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
      self.product = email_config.product
    elsif self.product
      self.email_config = self.product.primary_email_config
    end
    self.group_id ||= email_config.group_id unless email_config.nil?
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
    # using Digest::SHA2.hexdigest for a 64 char hash
    # using ticket id, current account id along with Time.now
    Digest::SHA2.hexdigest("#{Account.current.id}:#{self.id}:#{Time.now.to_f}")
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
    created_time = self.created_at.in_time_zone(Time.zone.name) || Time.zone.now
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
    ticket_states.sla_timer_stopped_at = Time.zone.now
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
    self.ff_def = FlexifieldDef.find_by_account_id_and_name(self.account_id, "Ticket_#{self.account_id}").id
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
    current_action_time = created_at || Time.zone.now
    if responder_id
      schema_less_ticket.set_first_assign_bhrs(current_action_time, ticket_states.first_assigned_at, self.group)
      schema_less_ticket.set_agent_assigned_flag
    end
    schema_less_ticket.set_group_assigned_flag if group_id
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
end
