class ApiDecorator
  attr_accessor :record

  delegate :created_at, :updated_at, :inspect, to: :record

  def initialize(record, _options = {})
    @record = record
  end

  # need to be overridden by the child class
  def attributes
    []
  end

  def attribute_values
    attributes.inject({}) do |attribute_hash, key|
      attribute_hash.merge({ key => safe_send(key.to_s) })
    end
  end

  def to_bool(field_to_be_converted)
    value = record.safe_send(field_to_be_converted)
    value ? value.to_s.to_bool : value
  rescue ArgumentError
    Rails.logger.error "API V2 Boolean convert error #{record.class} id #{record.id} with #{field_to_be_converted} is '#{value}'"
    value
  end

  def private_api?
    CustomRequestStore.read(:private_api_request)
  end

  def channel_v2_api?
    CustomRequestStore.read(:channel_api_request)
  end

  def public_v2_api?
    CustomRequestStore.read(:api_v2_request)
  end

  def format_date(value, utc_format = false)
    return utc_format ? value.utc : value.strftime('%F') if value.respond_to?(:utc)
    value
  end

  def app_current?
    Thread.current[:app_integration].present?
  end

  def current_account
    @current_account ||= Account.current
  end
end
