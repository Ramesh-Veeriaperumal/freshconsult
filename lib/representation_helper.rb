module RepresentationHelper

  def utc_format(date_time)
    date_time.try(:utc).try(:iso8601)
  end
  
  def central_publish_payload
    as_api_response(central_publish_template)
  end

  def publish_associations?
    self.class.method_defined? "api_accessible_#{central_publish_template}_associations".to_sym
  end

  def associations_to_publish
    as_api_response("#{central_publish_template}_associations")
  end

  def central_publish_template
    payload_template_mapping.fetch(self.central_payload_type, :central_publish)
  end

  def payload_template_mapping
    {}
  end

  def model_changes_for_central
    @model_changes || self.changes.try(:to_hash) || @manual_publish_changes
  end
end
