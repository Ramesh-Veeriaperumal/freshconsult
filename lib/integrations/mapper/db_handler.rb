class Integrations::Mapper::DBHandler
  include Integrations::AppsUtil

  def fetch(data, config)
    fetch = config.clone
    entity_type = fetch[:entity]
    find_or_initialize = fetch[:find_or_initialize]
    fetch_using = fetch[:using]
    replace_liquid_values(fetch_using, data)
    Rails.logger.debug "DBHandler:: account_id #{data["account_id"]}, fetch_using #{fetch_using.inspect}"
    fetched_entity = entity_type.find_by_account_id(data["account_id"], fetch_using || {})
    fetched_entity = self.create(data, config) if find_or_initialize and fetched_entity.blank?
    fetched_entity
  end

  def save(data, config)
    data.save!
  end

  def create(data, config)
    entity_type = config[:entity]
    entity_type.new
  end
end
