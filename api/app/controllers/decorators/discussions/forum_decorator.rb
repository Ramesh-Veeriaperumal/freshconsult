class Discussions::ForumDecorator < ApiDecorator
  delegate :id, :name, :description, :position, :forum_category_id, :forum_type, :forum_visibility, :topics_count, :posts_count, :customer_forums, to: :record

  def initialize(record, options)
    super
  end

  def to_hash
    {
      id: id,
      name: name,
      description: description,
      position: position,
      forum_category_id: forum_category_id,
      forum_type: forum_type,
      forum_visibility: forum_visibility,
      topics_count: topics_count,
      comments_count: posts_count
    }
  end

  def to_full_hash
    res = to_hash
    res[:company_ids] = customer_forums.pluck(:customer_id) if forum_visibility == 4
    res
  end
end
