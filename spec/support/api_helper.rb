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

  TICKET_ATTRIBS = ["cc_email", "created_at", "deleted", "delta", "description", "description_html", "display_id", "due_by", "email_config_id", "frDueBy", "fr_escalated", "group_id", "id", "isescalated", "notes", "owner_id", "priority", "requester_id", "responder_id", "source", "spam", "status", "subject", "ticket_type", "to_email", "trained", "updated_at", "urgent", "status_name", "requester_status_name", "priority_name", "source_name", "requester_name", "responder_name", "to_emails", "attachments", "custom_field"]

  TICKET_UPDATE_ATTRIBS = ["deleted", "display_id", "subject", "status_name", "requester_status_name", "priority_name", "source_name", "requester_name", "responder_name", "to_emails"]
  
  CONTACT_ATTRIBS = ["active", "address", "created_at", "customer_id", "deleted", "description", "email", "external_id", "fb_profile_id", "helpdesk_agent", "id", "job_title", "language", "mobile", "name", "phone", "time_zone", "twitter_id", "updated_at"]

  FORUM_ATTRIBS = ["created_at", "description", "id", "name", "position", "updated_at"]

end