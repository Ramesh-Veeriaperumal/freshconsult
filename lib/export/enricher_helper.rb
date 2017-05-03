module Export::EnricherHelper
	
  include MemcacheKeys

  ENRICHER_CLASSES_HASH = { :user => Export::PayloadEnricher::User, 
                            :company => Export::PayloadEnricher::Company, 
                            :ticket => Export::PayloadEnricher::Ticket }
  OBJECT = "object"

  def self.create_payload_enricher(sqs_message, enricher_config)
    model = sqs_message[OBJECT].to_sym
    ENRICHER_CLASSES_HASH[model].new(sqs_message, enricher_config) if ENRICHER_CLASSES_HASH[model]
  end

  def self.export_fields_data_from_cache
    MemcacheKeys.fetch(key) {
      Export::PayloadEnricher::ConfigHelper.new.construct_enricher_config
    }
  end

  def self.clear_export_payload_enricher_config
    MemcacheKeys.delete_from_cache(key)
  end

  private
  
  def self.key
    EXPORT_PAYLOAD_ENRICHER_CONFIG % {:account_id => Account.current.id}
  end
end