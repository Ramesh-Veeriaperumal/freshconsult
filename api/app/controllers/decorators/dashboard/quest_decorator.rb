class Dashboard::QuestDecorator < ApiDecorator
  delegate :id, :name, :description, :points, :badge_id, :category, :sub_category, to: :record
  def to_hash
    {
      id: id,
      name: name,
      description: description,
      points: points,
      badge_id: badge_id,
      category: category,
      sub_category: sub_category,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
  end
end
