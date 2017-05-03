class Export::PayloadEnricher::ConfigHelper

  def construct_enricher_config
    Export::PayloadEnricher::Config.new.tap do |config|
      scheduled_ticket_exports.each do |export|
        config.add_fields :ticket, (export.ticket_fields | export.filter_fields)
        config.add_fields :company, export.company_fields
        config.add_fields :user, export.user_fields
      end
    end
  end

  private

  def scheduled_ticket_exports
    Account.current.scheduled_ticket_exports_from_cache 
  end
  
end