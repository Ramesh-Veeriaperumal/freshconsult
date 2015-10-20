module Helpers::DiscussionsHelper
  include CompanyHelper
  include ForumHelper
  # Patterns
  def forum_category_response_pattern(name = 'test', desc = 'test desc')
    {
      id: Fixnum,
      name: name,
      description: desc,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def forum_category_pattern(fc)
    {
      id: Fixnum,
      name: fc.name,
      description: fc.description,
      created_at: fc.created_at,
      updated_at: fc.updated_at
    }
  end

  def forum_pattern(forum)
    {
      id: Fixnum,
      name: forum.name,
      description: forum.description,
      position: forum.position,
      description_html: forum.description_html,
      forum_category_id: forum.forum_category_id,
      forum_type: forum.forum_type,
      forum_visibility: forum.forum_visibility,
      topics_count: forum.topics_count,
      posts_count: forum.posts_count
    }
  end

  def forum_response_pattern(f = nil, hash = {})
    {
      id: Fixnum,
      name: hash[:name] || f.name,
      description: hash[:description] || f.description,
      position: hash[:position] || f.position,
      description_html: hash[:description_html] || f.description_html,
      forum_category_id: hash[:forum_category_id] || f.forum_category_id,
      forum_type: hash[:forum_type] || f.forum_type,
      forum_visibility: hash[:forum_visibility] || f.forum_visibility,
      topics_count: hash[:topics_count] || f.topics_count,
      posts_count: hash[:posts_count] || f.posts_count
    }
  end

  def topic_pattern(expected_output = {}, topic)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      title: expected_output[:title] || topic.title,
      forum_id: expected_output[:forum_id] || topic.forum_id,
      user_id: expected_output[:user_id] || topic.user_id,
      locked: (expected_output[:locked] || topic.locked).to_s.to_bool,
      sticky: (expected_output[:sticky] || topic.sticky).to_s.to_bool,
      published: (expected_output[:published] || topic.published).to_s.to_bool,
      stamp_type: expected_output[:stamp_type] || topic.stamp_type,
      replied_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      replied_by: expected_output[:replied_by] || topic.replied_by,
      posts_count: expected_output[:posts_count] || topic.posts_count,
      hits: expected_output[:hits] || topic.hits,
      user_votes: expected_output[:user_votes] || topic.user_votes,
      merged_topic_id: expected_output[:merged_topic_id] || topic.merged_topic_id,
      created_at: expected_output[:ignore_created_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:created_at],
      updated_at: expected_output[:ignore_updated_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:updated_at]
    }
  end

  def post_pattern(expected_output = {}, post)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      body: expected_output[:body] || post.body,
      body_html: expected_output[:body_html] || post.body_html,
      topic_id: expected_output[:topic_id] || post.topic_id,
      forum_id: expected_output[:forum_id] || post.forum_id,
      user_id: expected_output[:user_id] || post.user_id,
      answer: (expected_output[:output] || post.answer).to_s.to_bool,
      published: post.published.to_s.to_bool,
      spam: post.spam.nil? ? post.spam : post.spam.to_s.to_bool,
      trash: post.trash.to_s.to_bool,
      created_at: expected_output[:ignore_created_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:created_at],
      updated_at: expected_output[:ignore_updated_at] ? %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$} : expected_output[:updated_at]
    }
  end

  # Helpers
  def v2_category_payload
    category_params.to_json
  end

  def v1_category_payload
    { forum_category: category_params }.to_json
  end

  def v2_forum_payload(_fc = nil)
    forum_params.to_json
  end

  def v2_update_forum_payload
    forum_params.merge(forum_category_id: ForumCategory.first.id).to_json
  end

  def v1_forum_payload
    { forum: forum_params.merge(forum_category_id: ForumCategory.first.id) }.to_json
  end

  def v1_topics_payload(forum_id)
    { topic: topic_params.merge(sticky: 0, locked: 0, body_html: Faker::Lorem.characters, forum_id: forum_id) }.to_json
  end

  def v2_topics_payload(_f = nil)
    topic_params.merge(message_html: Faker::Lorem.characters).to_json
  end

  def v2_update_topics_payload(_f = nil)
    topic_params.merge(message_html: Faker::Lorem.characters, forum_id: Forum.first.id).to_json
  end

  def v1_post_payload(t)
    { post: post_params(t) }.to_json
  end

  def v2_post_payload(t)
    post_params(t).to_json
  end

  # private
  def category_params
    { name: Faker::Name.name,  description: Faker::Lorem.characters }
  end

  def forum_params
    { description: Faker::Lorem.characters,
      forum_type: 2, forum_visibility: 1, name: Faker::Name.name }
  end

  def topic_params
    { title: Faker::Name.name }
  end

  def post_params(_t)
    { body_html: Faker::Lorem.characters }
  end

  def user_without_monitorships
    u = User.includes(:monitorships).find { |x| x.id != @agent.id && x.monitorships.blank? } || add_new_user(@account) # changed as it should have user without any monitorship
    u.update_column(:email, Faker::Internet.email)
    u.reload
  end
end
