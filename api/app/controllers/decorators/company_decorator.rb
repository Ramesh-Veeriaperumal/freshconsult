class CompanyDecorator < ApiDecorator
  delegate :id, :name, :description, :note, :users, to: :record

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
    @sla_policies = options[:sla]
  end

  def custom_fields
    # @name_mapping will be nil for READ requests, hence it will computed for the first
    custom_fields_hash = {}
    record.custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = v }
    custom_fields_hash
  end

  def domains
    record.domains.nil? ? [] : record.domains.split(',')
  end

  def sla_policies
    @sla_policies.map { |item| SlaPolicyDecorator.new(item) }
  end

  def to_hash
    {
      id: id,
      name: name,
      description: description,
      note: note,
      domains: domains,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      custom_fields: custom_fields
    }
  end
end
