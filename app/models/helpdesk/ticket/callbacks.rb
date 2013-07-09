class Helpdesk::Ticket < ActiveRecord::Base

	before_validation :populate_requester, :set_default_values

	before_validation_on_create :set_token

  before_create :assign_flexifield, :assign_schema_less_attributes, :assign_email_config_and_product, :save_ticket_states

	before_update :assign_email_config

  before_update :update_message_id, :if => :deleted_changed?

  before_save :update_ticket_related_changes, :set_sla_policy, :load_ticket_status

  before_save :update_dueby, :unless => :manual_sla?

  after_create :refresh_display_id, :create_meta_note

  after_commit_on_create :create_initial_activity,  :update_content_ids, :pass_thro_biz_rules
  after_commit_on_update :filter_observer_events, :if => :user_present?
  after_commit_on_update :update_ticket_states, :notify_on_update, :update_activity, 
  :stop_timesheet_timers, :fire_update_event, :publish_to_update_channel, :regenerate_reports_data

  def set_default_values
    self.status = OPEN unless (Helpdesk::TicketStatus.status_names_by_key(account).key?(self.status) or ticket_status.try(:deleted?))
    self.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[:portal] if self.source == 0
    self.ticket_type = account.ticket_types_from_cache.first.value if self.ticket_type.blank? 
    self.subject ||= ''
    self.group_id ||= email_config.group_id unless email_config.nil?
    self.priority ||= PRIORITY_KEYS_BY_TOKEN[:low]
    build_ticket_body(:description_html => self.description_html,
      :description => self.description) unless ticket_body
  end

  def save_ticket_states
    self.ticket_states = Helpdesk::TicketState.new
    ticket_states.account_id = account_id
    ticket_states.assigned_at=Time.zone.now if responder_id
    ticket_states.first_assigned_at = Time.zone.now if responder_id
    ticket_states.pending_since=Time.zone.now if (status == PENDING)
    ticket_states.set_resolved_at_state if (status == RESOLVED)
    ticket_states.resolved_at ||= ticket_states.set_closed_at_state if (status == CLOSED)
    ticket_states.status_updated_at = Time.zone.now
    ticket_states.sla_timer_stopped_at = Time.zone.now if (ticket_status.stop_sla_timer?)
  end

  def update_ticket_states 
    ticket_states.assigned_at=Time.zone.now if (@model_changes.key?(:responder_id) && responder)    
    if (@model_changes.key?(:responder_id) && @model_changes[:responder_id][0].nil? && responder)
      ticket_states.first_assigned_at = Time.zone.now
    end
    if @model_changes.key?(:status)
      if reopened_now?
        ticket_states.opened_at=Time.zone.now
        ticket_states.reset_tkt_states
      end
      
      ticket_states.pending_since=Time.zone.now if (status == PENDING)
      ticket_states.set_resolved_at_state if (status == RESOLVED)
      ticket_states.set_closed_at_state if closed?
      
      ticket_states.status_updated_at = Time.zone.now
      if(ticket_status.stop_sla_timer)
        ticket_states.sla_timer_stopped_at ||= Time.zone.now 
      else
        ticket_states.sla_timer_stopped_at = nil
      end
    end    
    ticket_states.save
  end

  def refresh_display_id #by Shan temp
      self.display_id = Helpdesk::Ticket.find_by_id(id).display_id  if display_id.nil? #by Shan hack need to revisit about self as well.
  end

  def create_meta_note
      # Added for storing metadata from MobiHelp
      self.notes.create(
        :note_body_attributes => {:body => meta_data.map { |k, v| "#{k}: #{v}" }.join("\n")},
        :private => true,
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'],
        :account_id => self.account.id,
        :user_id => self.requester.id
      ) if meta_data.present?
  end

  def pass_thro_biz_rules
     send_later(:delayed_rule_check) unless import_id
  end
  
  def delayed_rule_check
   begin
    evaluate_on = check_rules     
    assign_tickets_to_agents unless spam? || deleted?
    autoreply
   rescue Exception => e #better to write some rescue code 
    NewRelic::Agent.notice_error(e)
   end
    save #Should move this to unless block.. by Shan
  end

  def assign_tickets_to_agents
    #Ticket already has an agent assigned to it or doesn't have a group
    return if group.nil? || self.responder_id
    schedule_round_robin_for_agents if group.round_robin_eligible?
  end 

  def schedule_round_robin_for_agents
    next_agent = group.next_available_agent

    return if next_agent.nil? #There is no agent available to assign ticket.
    self.responder_id = next_agent.user_id
    self.save
  end

  def check_rules
    evaluate_on = self
    account.va_rules.each do |vr|
      evaluate_on = vr.pass_through(self)
      return evaluate_on unless evaluate_on.nil?
    end
    return evaluate_on
  end

  def stop_timesheet_timers
    if @model_changes.key?(:status) && [RESOLVED, CLOSED].include?(status)
       running_timesheets =  time_sheets.find(:all , :conditions =>{:timer_running => true})
       running_timesheets.each{|t| t.stop_timer}
    end
   end

  def update_message_id
    if self.header_info
      self.header_info[:message_ids].each do |parent_message|
        message_key = EMAIL_TICKET_ID % {:account_id => self.account_id, :message_id => parent_message}
        deleted ? remove_others_redis_key(message_key) : set_others_redis_key(message_key, self.display_id, 86400*7)
      end
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
  end

  def changed_condition?
    group_id_changed? || source_changed? || has_product_changed? || ticket_type_changed?
  end

  def has_product_changed?
    self.schema_less_ticket.changes.key?('product_id') 
  end

  def update_dueby(ticket_status_changed=false)
    Thread.current[TicketConstants::GROUP_THREAD] = self.group
    set_sla_time(ticket_status_changed)
    Thread.current[TicketConstants::GROUP_THREAD] = nil
  end

  #shihab-- date format may need to handle later. methode will set both due_by and first_resp
  def set_sla_time(ticket_status_changed)
    if self.new_record?
      set_time_zone
      sla_detail = self.sla_policy.sla_details.find(:first, :conditions => {:priority => priority})
      set_dueby_on_priority_change(sla_detail)

      set_user_time_zone if User.current
      RAILS_DEFAULT_LOGGER.debug "sla_detail_id :: #{sla_detail.id} :: due_by::#{self.due_by} and fr_due:: #{self.frDueBy} " 
    elsif priority_changed? || changed_condition? || status_changed? || ticket_status_changed

      set_time_zone
      sla_detail = self.sla_policy.sla_details.find(:first, :conditions => {:priority => priority})

      set_dueby_on_priority_change(sla_detail) if (priority_changed? || changed_condition?)
      set_dueby_on_status_change(sla_detail) if status_changed? || ticket_status_changed
      set_user_time_zone if User.current
      RAILS_DEFAULT_LOGGER.debug "sla_detail_id :: #{sla_detail.id} :: due_by::#{self.due_by} and fr_due:: #{self.frDueBy} " 
    end 
  end
  #end of SLA
  
  def set_account_time_zone  
    self.account.make_current
    Time.zone = self.account.time_zone    
  end
 
  def set_user_time_zone 
    Time.zone = User.current.time_zone  
  end

private

  def update_ticket_related_changes
    @model_changes = self.changes.clone
    @model_changes.merge!(schema_less_ticket.changes.clone) unless schema_less_ticket.nil?
    @model_changes.merge!(flexifield.changes) unless flexifield.nil?
    @model_changes.symbolize_keys!
  end

  def load_ticket_status
    if !self.new_record? && status_changed?
      self.ticket_status = account.ticket_status_values.find_by_status_id(status)
    end
  end

  def populate_requester
    return if requester
    self.requester_id = nil
    unless email.blank?
      name_email = parse_email email  #changed parse_email to return a hash
      self.email = name_email[:email]
      self.name = name_email[:name]
      @requester_name ||= self.name # for MobiHelp
    end

    self.requester = account.all_users.find_by_an_unique_id({ 
      :email => self.email, 
      :twitter_id => twitter_id,
      :external_id => external_id })
    
    create_requester unless requester
  end

  def create_requester
    if can_add_requester?
      portal = self.product.portal if self.product
      requester = account.users.new
      requester.signup!({:user => {
        :email => email , :twitter_id => twitter_id, :external_id => external_id,
        :name => name || twitter_id || @requester_name || external_id,
        :helpdesk_agent => false, :active => email.blank? }}, 
        portal) # check @requester_name and active
      
      self.requester = requester
    end
  end

  def can_add_requester?
    email.present? || twitter_id.present? || external_id.present? 
  end

  def update_content_ids
    header = self.header_info
    return if attachments.empty? or header.nil? or header[:content_ids].blank?
    
    description_updated = false
    attachments.each do |attach| 
      content_id = header[:content_ids][attach.content_file_name]
      self.ticket_body.description_html = self.ticket_body.description_html.sub("cid:#{content_id}", attach.content.url) if content_id
      description_updated = true
    end

    ticket_body.update_attribute(:description_html,self.ticket_body.description_html) if description_updated

    # For rails 2.3.8 this was the only i found with which we can update an attribute without triggering any after or before callbacks
    #Helpdesk::Ticket.update_all("description_html= #{ActiveRecord::Base.connection.quote(description_html)}", ["id=? and account_id=?", id, account_id]) \
       # if description_updated
  end

  def assign_schema_less_attributes
    build_schema_less_ticket unless schema_less_ticket
    schema_less_ticket.account_id ||= account_id
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
    self.access_token ||= generate_token(Helpdesk::SECRET_2)     
  end

  def generate_token(secret)
    Digest::MD5.hexdigest(secret + Time.now.to_f.to_s)
  end

  def fire_update_event
    fire_event(:update, @model_changes) unless disable_observer
  end

  def publish_to_update_channel
    return unless account.features?(:agent_collision)
    agent_name = User.current ? User.current.name : ""
    message = HELPDESK_TICKET_UPDATED_NODE_MSG % {:ticket_id => self.id, :agent_name => agent_name, :type => "updated"}
    publish_to_tickets_channel("tickets:#{self.account.id}:#{self.id}", message)
  end

  def set_dueby_on_priority_change(sla_detail)
    created_time = self.created_at || Time.zone.now
    self.due_by = sla_detail.calculate_due_by_time_on_priority_change(created_time)      
    self.frDueBy = sla_detail.calculate_frDue_by_time_on_priority_change(created_time) 
  end

  def set_dueby_on_status_change(sla_detail)
    unless (ticket_status.stop_sla_timer or ticket_states.sla_timer_stopped_at.nil?)
      self.due_by = sla_detail.calculate_due_by_time_on_status_change(self)      
      self.frDueBy = sla_detail.calculate_frDue_by_time_on_status_change(self) 
    end
  end

  def regenerate_reports_data
    deleted_or_spam = @model_changes.keys & [:deleted, :spam]
    return unless deleted_or_spam.any? && (created_at.strftime("%Y-%m-%d") != updated_at.strftime("%Y-%m-%d"))
    set_reports_redis_key(account_id, created_at)
  end

  def manual_sla?
    self.manual_dueby && self.due_by && self.frDueBy
  end

  def assign_flexifield
    build_flexifield
    self.ff_def = FlexifieldDef.find_by_account_id_and_module(self.account_id, 'Ticket').id
    assign_ff_values custom_field
    @custom_field = nil
  end

end