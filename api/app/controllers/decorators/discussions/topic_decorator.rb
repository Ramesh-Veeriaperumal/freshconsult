class Discussions::TopicDecorator < ApiDecorator

  delegate :id, :title, :forum_id, :user_id, :locked, :published, :stamp_type, 
           :replied_by, :hits, :user_votes, :merged_topic_id, :replied_at, to: :record

  def comments_count
    record.posts_count
  end

  def sticky
    to_bool(:sticky)
  end
end
