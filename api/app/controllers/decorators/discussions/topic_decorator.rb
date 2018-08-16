class Discussions::TopicDecorator < ApiDecorator
  delegate :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, :forum, :topic_desc,
           :replied_by, :hits, :user_votes, :merged_topic_id, :replied_at, :created_at, :updated_at, :first_post, to: :record

  def comments_count
    record.posts_count
  end

  def sticky
    to_bool(:sticky)
  end

  def to_hash
    {
      id: id,
      title: title,
      forum_id: forum_id,
      user_id: user_id,
      locked: locked,
      published: published,
      stamp_type: stamp_type,
      replied_by: replied_by,
      user_votes: user_votes,
      merged_topic_id: merged_topic_id,
      comments_count: comments_count,
      sticky: sticky,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      replied_at: replied_at.try(:utc),
      hits: hits
    }
  end

  def to_search_hash
    category = forum.forum_category
    to_hash.merge(replied_by: replied_by,
                  category_id: category.id,
                  category_name: category.name,
                  forum_name: forum.name,
                  description_text: topic_desc)
  end
end
