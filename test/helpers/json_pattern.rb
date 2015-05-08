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
end

include JsonPattern
