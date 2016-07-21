class Helpdesk::Ticket < ActiveRecord::Base

  def count_fields_updated?
    fields_updated = (@model_changes.keys & count_es_columns).any?
    Rails.logger.info "COUNT ES:: account id:#{self.account_id}, display id: #{self.display_id}, fields updated: #{fields_updated}"
    fields_updated
  end

  def to_count_es_json
    as_json({
      :root => false,
      :tailored_json => true,
      :methods => [
                    :company_id, :tag_names, :tag_ids, :watchers, :status_stop_sla_timer, 
                    :status_deleted, :product_id, :trashed
                  ].concat(ticket_states_columns),
      :only => ticket_indexed_fields
      },false).merge(count_es_ff_fields).merge(schema_less_fields).to_json
  end

  def count_es_columns
    @@count_es_columns ||= ticket_indexed_fields.concat(ticket_states_columns).concat(count_es_ff_columns).concat(schema_less_columns)
  end

  def count_es_ff_columns
    @@count_es_ff_columns ||= Flexifield.column_names.select {|v| v =~ /^ff(s|_date|_int|_decimal|_boolean)/}.map(&:to_sym)
  end

  def ticket_states_columns
    [
      :resolved_at, :closed_at, :opened_at, :first_assigned_at, :pending_since, :assigned_at, :first_response_time,
      :requester_responded_at, :agent_responded_at, :group_escalated, :inbound_count, :outbound_count,
      :status_updated_at, :sla_timer_stopped_at, :outbound_count, :avg_response_time, :first_resp_time_by_bhrs,
      :resolution_time_by_bhrs, :avg_response_time_by_bhrs, :status_stop_sla_timer, :status_deleted,
      :tags
    ]
  end

  def ticket_indexed_fields
    [
      :requester_id, :responder_id, :status, :source, :spam, :deleted, 
      :created_at, :updated_at, :account_id, :display_id, :group_id, :owner_id, :due_by, :isescalated,
      :fr_escalated, :email_config_id, :frDueBy, :priority, :ticket_type, :product_id
    ]
  end

  def schema_less_columns
     @@schema_less_columns ||= Helpdesk::SchemaLessTicket.column_names.select {|v| v =~ /^long|int|datetime|string|boolean_/}.map(&:to_sym)
  end

  def schema_less_fields
    schema_less_ticket.as_json(root: false, only: schema_less_columns)
  end

  def count_es_ff_fields
    flexifield.as_json(root: false, only: count_es_ff_columns)
  end


end