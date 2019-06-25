class Export::PayloadEnricher::Base

  DESTROY = "destroy"
  ACTION = "action"
  ID = "id"

  def initialize(sqs_msg, enricher_config)
    @sqs_msg         = sqs_msg
    @enricher_config = enricher_config
  end

  def collect_properties(fields_to_export)
    from_object = fetch_object
    response_map = {}
    if from_object
      fields_to_export.inject(response_map) do |properties_map, field_name|
        properties_map[field_name] = field_value(from_object, field_name)
        properties_map
      end
    end
    response_map
  end

  def field_value(object, name)
    object.safe_send(name)
  rescue Exception => e
    Rails.logger.error "Enricher Method missing #{e.message}"
    return nil
  end

  def enrich
    @sqs_msg.tap do |sqs_msg|
      sqs_msg[property_key].merge!(properties) if sqs_msg[ACTION] != DESTROY
    end
  end

  def latest_ticket_change?
    true
  end

end
