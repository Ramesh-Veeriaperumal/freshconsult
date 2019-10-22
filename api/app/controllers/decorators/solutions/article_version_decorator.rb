class Solutions::ArticleVersionDecorator < ApiDecorator
  delegate :version_no, :meta, :user_id, :created_at, :updated_at, :published_by, :title, :description, :published_by, :live, :status, :published?, :discarded?, :discarded_by, to: :record

  def to_hash
    result = to_common_hash
    result[:published_by] = published_by
    result[:title] = title
    result[:description] = description
    result[:attachments] = attachments_hash
    result[:cloud_files] = cloud_files_hash
    result
  end

  def attachments_hash
    attachments = meta[:attachments] || []
    attachment_ids = attachments.map { |attachement| attachement[:id] }
    valid_attachments = if attachment_ids.present?
      Account.current.attachments.where(id: attachment_ids).pluck(:id)
    else
      []
    end
    attachments.map do |attachement|
      attachement[:deleted] = !valid_attachments.include?(attachement[:id])
      attachement
    end
    attachments
  end

  def cloud_files_hash
    meta[:cloud_files] || []
  end

  def to_common_hash
    result = {
      id: version_no,
      created_at: created_at,
      updated_at: updated_at,
      user_id: user_id,
      status: status
    }

    if discarded?
      result[:discarded_by] = discarded_by
    elsif published?
      result[:live] = live
    end
    result
  end

  alias to_index_hash to_common_hash
end
