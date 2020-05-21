class Solutions::TemplateDecorator < ApiDecorator
  delegate :id, :title, :description, :user_id, :modified_by, :modified_at,
           :is_active, :is_default, :created_at, :solution_template_mappings, to: :record

  def to_index_hash
    {
      id: id,
      title: title,
      agent_id: user_id,
      modified_by: modified_by,
      modified_at: modified_at,
      is_active: is_active,
      is_default: is_default,
      created_at: created_at,
      usage: used_in_articles_count
    }
  end

  def to_hash
    to_index_hash.merge(description: description)
  end

  private

    def used_in_articles_count
      solution_template_mappings.size
    end
end
