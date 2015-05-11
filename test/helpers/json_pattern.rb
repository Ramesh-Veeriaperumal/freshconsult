module JsonPattern
  def forum_category_response_pattern name="test", desc="test desc"
    {
    	id: Fixnum,
      name: name,
      description: desc,
      position: Fixnum,
      created_at:/^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/,
      updated_at:/^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/
    }
  end

  def forum_category_pattern fc
    {
      id: Fixnum,
      name: fc.name,
      description: fc.description,
      position: fc.position,
      created_at: fc.created_at,
      updated_at: fc.updated_at
    }
  end

  def bad_request_error_pattern field, value, params_hash={}
    {
      field: "#{field}", 
      message: I18n.t("api.error_messages.#{value}", params_hash), 
      code: ApiError::BaseError::API_ERROR_CODES_BY_VALUE[value]
    }
  end

  def too_many_request_error_pattern
    {
      message: String
    } 
  end

  def invalid_json_error_pattern
    {
      code: "invalid_json",
      message: String
    } 
  end

  def request_error_pattern code, params_hash={}
    {
      code: code, 
      message: I18n.t("api.error_messages.#{code}", params_hash)
    }
  end

  def base_error_pattern code, params_hash={}
    {
      message: I18n.t("api.error_messages.#{code}", params_hash)
    }
  end

   def forum_pattern forum
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

  def forum_response_pattern f=nil, hash={}
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

  def topic_pattern expected_output={}, topic
   expected_output[:ignore_created_at] ||= true
   expected_output[:ignore_updated_at] ||= true
    {
       id: Fixnum,
       title: expected_output[:title] || topic.title, 
       forum_id: expected_output[:forum_id] || topic.forum_id, 
       user_id: expected_output[:user_id] || topic.user_id, 
       locked: expected_output[:locked] || topic.locked, 
       sticky: expected_output[:sticky] || topic.sticky, 
       published: expected_output[:published] || topic.published, 
       stamp_type: expected_output[:stamp_type] || topic.stamp_type, 
       replied_at: /^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/, 
       replied_by: expected_output[:replied_by] || topic.replied_by,
       posts_count: expected_output[:posts_count] || topic.posts_count, 
       hits: expected_output[:hits] || topic.hits, 
       user_votes: expected_output[:user_votes] || topic.user_votes, 
       merged_topic_id: expected_output[:merged_topic_id] || topic.merged_topic_id,
       created_at: expected_output[:ignore_created_at] ? /^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/ : expected_output[:created_at],
       updated_at: expected_output[:ignore_updated_at] ? /^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/ : expected_output[:updated_at]
    }
  end

  def post_pattern expected_output={}, post
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum, 
      body: expected_output[:body] || post.body, 
      body_html: expected_output[:body_html] || post.body_html, 
      topic_id: expected_output[:topic_id] || post.topic_id, 
      forum_id: expected_output[:forum_id] || post.forum_id, 
      user_id: expected_output[:user_id] || post.user_id, 
      answer: expected_output[:output] || post.answer, 
      published:post.published, 
      spam: post.spam, 
      trash: post.trash,
      created_at: expected_output[:ignore_created_at] ? /^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/ : expected_output[:created_at],
      updated_at: expected_output[:ignore_updated_at] ? /^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$/ : expected_output[:updated_at]
    }
  end

end

include JsonPattern
