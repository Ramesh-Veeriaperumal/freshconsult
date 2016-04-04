class ApiDecorator
  attr_accessor :record

  delegate :created_at, :updated_at, :inspect, to: :record

  def initialize(record, _options = {})
    @record = record
  end

  def to_bool(field_to_be_converted)
    value = record.send(field_to_be_converted)
    value ? value.to_s.to_bool : value
  rescue ArgumentError => ex
    Rails.logger.error "API V2 Boolean convert error #{record.class} id #{record.id} with #{field_to_be_converted} is '#{value}'"
    value
  end
end
