module APIHelper

  SKIPPED_KEYS = [:created_at, :updated_at, :id]

  def xml skipped_keys = SKIPPED_KEYS # Converts xml string to hash
    @xml ||= deep_skip_keys(Hash.from_trusted_xml(response.body).deep_symbolize_keys, skipped_keys)
  end

  def json skipped_keys = SKIPPED_KEYS # Converts json string to hash
    @json ||= deep_skip_keys(JSON.parse(response.body).deep_symbolize_keys, skipped_keys)
  end

  def deep_skip_keys array_or_hash, skipped_keys
    if array_or_hash.is_a? Hash
      array_or_hash.each do |key, value|
        array_or_hash.delete(key) if skipped_keys.include? key
        array_or_hash[key] = deep_skip_keys(value, skipped_keys) if(value.is_a?(Hash) || value.is_a?(Array))
      end
    end
    if array_or_hash.is_a? Array
      array_or_hash.each do |element|
        element = deep_skip_keys(element, skipped_keys) if(element.is_a?(Hash) || element.is_a?(Array))
      end
    end
    array_or_hash
  end

  def clear_xml
    @xml = nil
  end

  def clear_json
    @json = nil
  end

  def clear_xml_and_json
    clear_xml
    clear_json
  end

  TICKET_ATTRIBS = ["cc_email", "created_at", "deleted", "delta", "description", "description_html", "display_id", "due_by", "email_config_id", "frDueBy", "fr_escalated", "group_id", "id", "isescalated", "notes", "owner_id", "priority", "requester_id", "responder_id", "source", "spam", "status", "subject", "ticket_type", "to_email", "trained", "updated_at", "urgent", "status_name", "requester_status_name", "priority_name", "source_name", "requester_name", "responder_name", "to_emails", "product_id", "attachments", "custom_field","tags"]
  
  NOTE_ATTRIBS = ["body", "body_html", "created_at", "deleted", "id", "incoming", "private", "source", "updated_at", "user_id", "attachments", "support_email"]

  ATTACHMENT_ATTRIBS = ["content_content_type", "content_file_name", "content_file_size", "created_at", "id", "updated_at", "attachment_url"]

  TICKET_UPDATE_ATTRIBS = ["deleted", "display_id", "subject", "status_name", "requester_status_name", "priority_name", "source_name", "requester_name", "responder_name", "to_emails", "product_id"]
  
  CONTACT_ATTRIBS = ["active", "address", "created_at", "customer_id", "deleted", "description", "email", "external_id", "fb_profile_id", "helpdesk_agent", "id", "job_title", "language", "mobile", "name", "phone", "time_zone", "twitter_id", "updated_at", "company_id", "custom_field"]
 
  COMPANY_ATTRIBS  = ["created_at", "cust_identifier", "description", "domains", "id", "name", "note", "sla_policy_id", "updated_at","custom_field"]

  AGENT_USER_ATTRIBS =  ["active", "address", "created_at", "customer_id", "deleted", "description", "email", "external_id", "fb_profile_id", "helpdesk_agent", "id", "job_title", "language", "mobile", "name", "phone", "time_zone", "twitter_id", "updated_at", "company_id"]

  FORUM_CATEGORY_ATTRIBS = ["created_at", "description", "id", "name", "position", "updated_at"]

  FORUM_ATTRIBS = ["description", "description_html", "forum_category_id", "forum_type", "forum_visibility", "id", "name", "position", "posts_count", "topics_count"]

  MONITOR_ATTRIBS = ["active" ,"id","monitorable_id","monitorable_type","portal_id","user_id"]

  TOPIC_ATTRIBS = ["account_id", "created_at", "delta", "forum_id", "hits", "id", "import_id", "last_post_id", "locked", "merged_topic_id", "posts_count", "published", "replied_at", "replied_by", "stamp_type", "sticky", "title", "updated_at", "user_id", "user_votes"]

  POST_ATTRIBS = ["answer", "body", "body_html", "created_at", "forum_id", "id", "published", "spam", "topic_id", "trash", "updated_at", "user_id", "user_votes"]

  SOLUTION_CATEGORY_ATTRIBS = ["created_at", "description", "id", "is_default", "language_id", "name", "parent_id", "position", "updated_at"]

  SOLUTION_FOLDER_ATTRIBS = ["category_id", "created_at", "description", "id", "is_default", "language_id", "name", "parent_id", "position", "updated_at", "visibility"]

  SOLUTION_ARTICLE_ATTRIBS = ["art_type", "bool_01", "created_at", "datetime_01", "delta", "desc_un_html", "description", "folder_id", "hits", "id", "int_01", "int_02", "int_03", "language_id", "modified_at", "modified_by", "outdated", "parent_id", "position", "seo_data", "status", "string_01", "string_02", "thumbs_down", "thumbs_up", "title", "updated_at", "user_id", "tags", "folder"]

  SURVEY_ATTRIBS = ["agent_id", "created_at", "customer_id", "group_id", "id", "rating", "response_note_id", "survey_id", "surveyable_id", "surveyable_type", "updated_at"]

  TIME_ENTRY_ATTRIBS = ["billable", "created_at", "executed_at", "id", "note", "start_time", "timer_running", "updated_at", "user_id", "workable_type", "ticket_id", "agent_name", "timespent", "agent_email", "customer_name", "contact_email"]

  GROUP_ATTRIBS = ["assign_time", "business_calendar_id", "created_at", "description", "escalate_to", "id", "name", "ticket_assign_type","updated_at", "agents"]
   
  USER_ATTRIBS = ["active", "address", "created_at", "deleted", "description", "email", "external_id", "fb_profile_id", "helpdesk_agent", "id", "job_title", "language", "mobile", "name", "phone", "time_zone", "twitter_id", "updated_at"]
  
  AGENT_ATTRIBS = ["active_since","available", "created_at", "id", "occasional", "points", "scoreboard_level_id", "signature", "signature_html", "ticket_permission", "updated_at", "user_id", "user"]

  CONTACT_FIELDS_ATTRIBS = ["created_at", "deleted", "editable_in_portal", "editable_in_signup", "field_options", "id", "label", "label_in_portal", "name", "position", "required_for_agent", "required_in_portal", "updated_at", "visible_in_portal", "field_type", "choices"]

  COMPANY_FIELDS_ATTRIBS = ["created_at", "deleted", "field_options", "id", "label", "name", "position", "required_for_agent", "updated_at", "field_type", "choices"]

  ROLE_ATTRIBS = ["created_at", "default_role", "description", "id", "name", "updated_at"]

  TICKET_FIELDS_ATTRIBS = ["active", "created_at", "default", "description", "editable_in_portal", "field_options", "field_type", "flexifield_def_entry_id","id", "import_id", "label", "label_in_portal", "level", "name", "parent_id", "position", "prefered_ff_col", "required", "required_for_closure", "required_in_portal", "updated_at", "visible_in_portal", "choices", "nested_ticket_fields"]

end
