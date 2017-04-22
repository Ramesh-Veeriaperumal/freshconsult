class Export::PayloadEnricher::Base

  DESTROY = "destroy"
  ACTION = "action"
  ID = "id"

  def collect_properties(fields_to_export)
    fields_to_export.inject({}) do |properties_hash, field_name|
      @from_object ||= fetch_object
      properties_hash[field_name] = field_value(@from_object, field_name)
      properties_hash
    end
  end

  def field_value(object, name)
    object.send(name)
  rescue Exception => e
    Rails.logger.error "[Export::PayloadEnricher::Base] Exception occured while 
        trying to get value for property: #{name} on object class: 
        #{object.class.name}, id: #{object.id}, acc_id: #{object.account_id}, 
        Exception => #{e.message} - #{e.backtrace.inspect}"
    return nil
  end

end