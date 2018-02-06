module RepresentationHelper

  def utc_format(date_time)
    date_time.try(:utc).try(:iso8601)
  end
  
  def central_publish_payload(payload_type = nil)
    as_api_response(payload_template_mapping.fetch(payload_type, :central_publish))
  end

  def payload_template_mapping
    {}
  end

  def model_changes_for_central
    @model_changes || self.changes.try(:to_hash) || @manual_publish_changes
  end
end
