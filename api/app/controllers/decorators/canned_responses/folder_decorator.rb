class CannedResponses::FolderDecorator < ApiDecorator
  delegate :id, :visible_responses_count, :personal?, to: :record

  def name
    record.display_name
  end

end