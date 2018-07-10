class Segments::FilterDecorator < ApiDecorator
  def to_hash
    {
      id: record.id,
      name: record.name,
      query_hash: record.data,
      created_at: record.created_at,
      updated_at: record.updated_at
    }
  end
end
