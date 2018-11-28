class CannedResponses::FolderDecorator < ApiDecorator
  delegate :id, :visible_responses_count, :personal?, to: :record

  def name
    record.display_name
  end

  def to_hash
    {
      id: id,
      name: name
    }
  end
end
