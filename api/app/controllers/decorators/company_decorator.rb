class CompanyDecorator
  attr_accessor :record

  delegate :id, :name, :description, :note, :created_at, :updated_at, to: :record

  def initialize(record, options)
    @record = record
    @name_mapping = options[:name_mapping]
  end

  def custom_fields
    # @name_mapping will be nil for READ requests, hence it will computed for the first
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k.to_sym]] = v }
    custom_fields_hash
  end

  def domains
    record.domains.nil? ? [] : record.domains.split(',')
  end
end
