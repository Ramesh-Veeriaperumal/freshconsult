class Helpdesk::Ticket < ActiveRecord::Base

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
    BusinessCalendar.execute(self, {:dueby_calculation => true}) { 
      set_sla_time(ticket_status_changed) 
    } if update_dueby? && !disable_sla_calculation
  end

  def set_sla_time(ticket_status_changed)
    sla_detail = self.sla_policy.sla_details.where(:priority => priority).first
    set_dueby(sla_detail)
    log_dueby(sla_detail, "New SLA logic")
  end

  def set_dueby(sla_detail)
    created_time = self.created_at || time_zone_now
    total_time_worked = ticket_states.on_state_time.to_i
    business_calendar = Group.default_business_calendar(group)
    set_sla_calculation_time_at_with_zone if update_sla
    self.due_by = sla_detail.calculate_due_by(created_time, sla_calculation_time, total_time_worked, business_calendar)
    self.frDueBy = sla_detail.calculate_frDue_by(created_time, sla_calculation_time, total_time_worked, business_calendar) if self.ticket_states.first_response_time.nil?
  end

  def calculate_dueby_and_frdueby?
    changed_to_sla_timer_calculated_status? || changed_from_sla_timer_stopped_status_to_closed_or_resolved?
  end

  def changed_to_sla_timer_calculated_status?
    !(ticket_status.stop_sla_timer || ticket_states.sla_timer_stopped_at.nil?)
  end

  def changed_from_sla_timer_stopped_status_to_closed_or_resolved?
    changed_to_closed_or_resolved? && previous_state_was_sla_stop_state? && !previous_state_was_resolved_or_closed?
  end

  def changed_to_closed_or_resolved?
    [CLOSED, RESOLVED].include?(ticket_status.status_id)
  end

  def previous_state_was_resolved_or_closed?
    tkt_status = @model_changes ? @model_changes[:status][0] : self.changes[:status][0]
    [RESOLVED,CLOSED].include?(tkt_status)
  end

  def previous_state_was_sla_stop_state?
    previous_ticket_status.stop_sla_timer? 
  end

  def previous_ticket_status
    previous_status_id = @model_changes[:status][0]
    Helpdesk::TicketStatus.status_objects_from_cache(account).find{ |x| x.status_id == previous_status_id } || 
    account.ticket_statuses.where(:status_id => previous_status_id).first
  end

  def manual_sla?
    self.manual_dueby && self.due_by && self.frDueBy
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

  def common_updation_condition
    self.new_record? || priority_changed? || group_id_changed? || self.schema_less_ticket.sla_policy_id_changed?
  end

  def update_on_state_time?
    (self.new_record? || self.ticket_states.resolution_time_updated_at.present?) && 
      (common_updation_condition || (status_changed? && stop_sla_timer_changed?)) && 
      !disable_sla_calculation
  end

  def update_dueby?
    update_sla || common_updation_condition || (status_changed? && calculate_dueby_and_frdueby?) && !service_task?
  end

  def update_on_state_time
    self.ticket_states ||= Helpdesk::TicketState.new
    self.ticket_states.resolution_time_updated_at = time_zone_now
    Rails.logger.debug "SLA :::: Account id #{self.account_id} :: #{self.new_record? ? 'New' : self.id} ticket :: Updating resolution time :: resolution_time_updated_at :: #{self.ticket_states.resolution_time_updated_at}"
    if self.ticket_states.sla_timer_stopped_at.nil? && !self.new_record?
      ticket_states.change_on_state_time(ticket_states.resolution_time_updated_at_was, ticket_states.resolution_time_updated_at)
    end
  end

  def log_dueby sla_detail, logic
    sla_policy = self.sla_policy
    Rails.logger.debug "SLA :::: Account id #{self.account_id} :: #{self.new_record? ? 'New' : self.id} ticket :: Sla on background #{update_sla} :: Calculated due time using #{logic} :: sla_policy #{sla_policy.id} - #{sla_policy.name} sla_detail :: #{sla_detail.id} - #{sla_detail.name} :: due_by::#{self.due_by} and fr_due:: #{self.frDueBy}"
    Rails.logger.debug "SLA :::: Account id #{self.account_id} :: #{self.new_record? ? 'New' : self.id} #{self.display_id} ticket :: SLA calculation time :: #{sla_calculation_time} #{sla_calculation_time.to_i} :: Sla state attributes :: #{sla_state_attributes.inspect}" if update_sla
  end

  def stop_sla_timer_changed?
    @stop_sla_timer_changed ||= @model_changes.key?(:status) && 
    (previous_ticket_status.stop_sla_timer != ticket_status.stop_sla_timer)
  end

  def sla_state_attributes
    SLA_STATE_ATTRIBUTES.each_with_object({}) do |_attr, _object|
      _object[_attr] = safe_send(_attr).to_i
    end
  end

  def is_in_same_sla_state?(sla_attributes_on_enqueue)
    Rails.logger.debug "SLA :::: Account id #{self.account_id} :: #{self.new_record? ? 'New' : self.id} #{self.display_id} Enqueued sla state attributes :: #{sla_attributes_on_enqueue.inspect}"
    sla_attributes_on_enqueue.all? do |_attr, _value|
      Rails.logger.debug "SLA State check #{_attr} :: #{_value} :: #{safe_send(_attr).to_i}"
      safe_send(_attr).to_i == _value
    end
  end

  def set_sla_calculation_time_at_with_zone
    @sla_calculation_time = Time.zone.at(sla_calculation_time)
  end

end
