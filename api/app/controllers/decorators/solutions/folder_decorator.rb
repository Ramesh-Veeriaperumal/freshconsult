class Solutions::FolderDecorator < ApiDecorator
  delegate :name, :description, :parent_id, to: :record

  def company_ids_visible?
    parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end

  def parent
    @parent ||= record.parent
  end

  def company_ids
    parent.customer_folders.map(&:customer_id)
  end
end
