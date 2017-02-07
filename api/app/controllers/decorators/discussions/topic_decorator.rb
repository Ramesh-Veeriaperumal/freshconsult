class Discussions::TopicDecorator < ApiDecorator
  delegate :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type,
           :replied_by, :hits, :user_votes, :merged_topic_id, :replied_at, :created_at, :updated_at, to: :record

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

  alias_method :to_search_hash, :to_hash
end
