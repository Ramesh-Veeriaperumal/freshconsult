['forum_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module ModelsDiscussionsTestHelper
  include ForumHelper

  def central_publish_post_pattern(post)
    {
      id: post.id,
      user_id: post.user_id,
      topic_id: post.topic_id,
      forum_id: post.forum_id,
      account_id: post.account_id,
      answer: post.answer,
      import_id: post.import_id,
      published: post.published,
      spam: post.spam,
      trash: post.trash,
      user_votes: post.user_votes,
      comment: !post.original_post?,
      created_at: post.created_at.try(:utc).try(:iso8601),
      updated_at: post.updated_at.try(:utc).try(:iso8601)
    }
  end

  def central_publish_post_association_pattern(expected_output = {})
    {
      user: Hash
    }
  end
end