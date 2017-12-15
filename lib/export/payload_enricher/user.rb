class Export::PayloadEnricher::User < Export::PayloadEnricher::Base

  USER_PROPERTIES = "user_properties"
  DEFAULT_FIELDS  = %w(id).freeze

  def initialize(sqs_msg, enricher_config, user_id=nil)
    super(sqs_msg, enricher_config)
    @user_id = (sqs_msg.present? && sqs_msg[USER_PROPERTIES].present?) ? sqs_msg[USER_PROPERTIES][ID] : user_id
  end

  def queue_name
    :scheduled_user_export_queue
  end

  def properties
    collect_properties(@enricher_config.user_fields | DEFAULT_FIELDS)
  end

  def property_key
    USER_PROPERTIES
  end

  private

  def fetch_object
    @user ||= Account.current.all_users.find_by_id(@user_id)
  end
  
end
