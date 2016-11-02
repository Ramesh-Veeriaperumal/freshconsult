class SlaPolicyDecorator < ApiDecorator
  class << self
    def pluralize_conditions(input_hash)
      return_hash = {}
      input_hash.each { |key, value| return_hash[key.to_s.pluralize] = value } if input_hash
      return_hash
    end
  end

  def initialize(record)
    super(record)
  end

  def to_hash
    {
      id: record.id,
      name: record.name,
      description: record.description,
      active: record.active,
      applicable_to: self.class.pluralize_conditions(record.conditions),
      is_default: record.is_default,
      position: record.position,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
  end
end
