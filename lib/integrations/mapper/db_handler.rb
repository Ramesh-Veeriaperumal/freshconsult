class Integrations::Mapper::DBHandler
  include Integrations::AppsUtil

  def fetch(data, config)
    fetch = config.clone
    entity_type = fetch[:entity]
    fetch_using = fetch[:using]
    replace_liquid_values(fetch_using, data)
    Rails.logger.debug "DBHandler:: account_id #{data["account_id"]}, fetch_using #{fetch_using.inspect}"
    fetched_entity = fetch_using.blank? ? nil : entity_type.find_by_account_id(data["account_id"], fetch_using)
    if fetched_entity.blank?
      fetched_entity = self.create(data, config) unless fetch[:create_if_empty].blank?
      fetched_entity = data[fetch[:use_if_empty]] unless fetch[:use_if_empty].blank?
    end
    fetched_entity = fetched_entity[fetch[:field_type]] if fetch[:data_type] && fetch[:field_type] && fetched_entity
    fetched_entity
  end

  def save(data, config)
    if data.is_a?(Helpdesk::Ticket) 
      data.save_ticket! 
    elsif data.is_a?(Helpdesk::Note)
      data.save_note!
    else
      data.save!   
    end
  end

  def create(data, config)
    entity_type = config[:entity]
    if config[:create_params]
     replace_liquid_values(config[:create_params], data)
     entity_type.new(config[:create_params]) 
    else
      entity_type.new
    end
  end
end
