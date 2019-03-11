class Solutions::FolderDecorator < ApiDecorator
  delegate :id, :name, :description, :parent_id, :primary_folder, :solution_article_meta, :position, to: :record

  delegate :position, :article_order, to: :parent

  def to_hash
    response_hash = {
      id: parent_id,
      name: name,
      description: description,
      visibility: parent.visibility,
      created_at: created_at,
      updated_at: updated_at
    }
    response_hash[:company_ids] = company_ids if company_ids_visible?
    response_hash[:category_id] = category_id if private_api?
    response_hash[:position] = position if private_api?
    response_hash[:article_order] = article_order if private_api?
    response_hash
  end

  def company_ids_visible?
    parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end

  def parent
    @parent ||= record.parent
  end

  def company_ids
    parent.customer_folders.map(&:customer_id)
  end

  def category_id
    parent.solution_category_meta_id
  end

  def summary_hash
    {
      id: id,
      name: primary_folder.name,
      language_id: primary_folder.language_id,
      articles_count: articles_count,
      position: position
    }
  end

  private

    def articles_count
      solution_article_meta.length
    end
end
