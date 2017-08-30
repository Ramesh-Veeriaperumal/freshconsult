class Export::PayloadEnricher::Company < Export::PayloadEnricher::Base 

  COMPANY_PROPERTIES = "company_properties"
  DEFAULT_FIELDS     = %w(id).freeze

  def initialize(sqs_msg, enricher_config, company_id=nil)
    super(sqs_msg, enricher_config)
    @company_id = (sqs_msg.present? && sqs_msg[COMPANY_PROPERTIES].present?) ? sqs_msg[COMPANY_PROPERTIES][ID] : company_id
  end

  def queue_name
    :scheduled_company_export_queue
  end

  def properties
    collect_properties(@enricher_config.company_fields | DEFAULT_FIELDS)
  end

  def property_key
    COMPANY_PROPERTIES
  end

  private
  
  def fetch_object
    @company ||= Account.current.companies.find_by_id(@company_id)
  end
end