module RabbitMq::Subscribers::TimeSheets::Activities

  include RabbitMq::Constants
  include ActivityConstants
  
  PROPERTIES_TO_CONSIDER    = [:timer_running, :time_spent, :billable, :user_id, :executed_at]
  PROPERTIES_NOT_FOR_DELETE = [:timer_running]

  def mq_activities_time_sheet_properties(action)
    to_rmq_json(timesheet_keys,action)
  end

  def mq_activities_subscriber_properties(action)
    { :object_id => self.workable.display_id, :content => timesheet_properties(action) }
  end

  def mq_activities_valid(action, model)
    Account.current.features?(:activity_revamp) and timesheet_valid?(action)
  end

  private

  def timesheet_valid?(action)
    self.workable.is_a?(Helpdesk::Ticket) and (valid_changes.any? || destroy_action?(action))
  end

  def timesheet_properties(action)
    if destroy_action?(action) 
      property_hash = values_for_destroy
      {:timesheet_delete => property_hash}
    elsif create_action?(action)
      property_hash = values_for_create
      {:timesheet_create => property_hash}
    else
      property_hash = values_for_update
      {:timesheet_edit => property_hash}
    end
  end

  def values_for_destroy
    values = {}
    PROPERTIES_TO_CONSIDER.each do |property|
      values.merge!({:"#{property}" => [self.send(property), nil]}) if !PROPERTIES_NOT_FOR_DELETE.include?(property)
    end
    values
  end

  def values_for_create
    value_hash = valid_changes
    value_hash.has_key?(:billable) ? value_hash : value_hash.merge!({:billable => [nil, true]})
  end

  def values_for_update
    value_hash = valid_changes
    PROPERTIES_TO_CONSIDER.each do |property|
      value_hash.merge!(:"#{property}" => [self.send(property), self.send(property)]) if !value_hash.keys.include?(property) and !PROPERTIES_NOT_FOR_DELETE.include?(property)
    end
    value_hash
  end

  def valid_changes
    changes = previous_changes.symbolize_keys.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) }
    previous_changes.has_key?(:note) ? discard_note_changes(changes) : changes
  end

  def discard_note_changes(changes)
    value = (changes.keys.count == 1 and changes.has_key?(:executed_at) and !executed_at_changed?(changes))
    value ? {} : changes
  end

  def executed_at_changed?(changes)
    !(changes[:executed_at][0] == changes[:executed_at][1])
  end

  def timesheet_keys
    ACTIVITIES_TIMESHEET_KEYS
  end
end