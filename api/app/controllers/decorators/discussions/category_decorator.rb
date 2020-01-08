class Discussions::CategoryDecorator < ApiDecorator
  delegate :id, :name, :description, to: :record

  def initialize(record, options)
    super
  end

  def to_hash
    {
      id: id,
      name: name,
      description: description,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end
end
