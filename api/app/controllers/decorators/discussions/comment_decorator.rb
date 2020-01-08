class Discussions::CommentDecorator < ApiDecorator
  delegate :id, :user_id, :topic_id, :body, :forum_id, :body_html, :topic, :original_post?,
           :account_id, :answer, :published, :spam, :trash, :user_votes, to: :record

  def to_activity_hash
    ret = {
      activity_type: 'Post'.downcase,
      id: id,
      topic_id: topic.id,
      title: topic.title,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      comment: !original_post?,
      forum: forum_hash(topic.forum)
    }
  end

  def forum_hash(forum)
    {
      id: forum.id,
      name: forum.name
    }
  end

  def to_full_hash
    res = to_activity_hash.except(:activity_type, :title, :comment, :forum)
    res.merge(
      user_id: user_id,
      forum_id: forum_id,
      answer: answer,
      published: published,
      spam: spam,
      trash: trash,
      body: body_html,
      body_text: body
    )
  end
end
