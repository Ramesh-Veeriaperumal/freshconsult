class ApiDecorator
  attr_accessor :record

  delegate :created_at, :updated_at, :inspect, to: :record

  def initialize(record, _options = {})
    @record = record
  end
end
