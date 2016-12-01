class CloudFileDecorator < ApiDecorator

  def initialize(record, options = {})
    super(record)
  end

  def to_hash
    {
      id: record.id,
      name: record.filename,
      url: record.url,
      application_id: record.application_id,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
  end
end
