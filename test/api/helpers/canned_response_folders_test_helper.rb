module CannedResponseFoldersTestHelper

  def canned_response_sample_params(folder_id = nil, visibility = nil)
    {
      title: Faker::Lorem.sentence,
      content_html: 'Hi {{ticket.requester.name}}, Faker::Lorem.paragraph Regards, {{ticket.agent.name}}',
      visibility: visibility || Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
      folder_id: folder_id
    }
  end

  def create_canned_response(folder_id, visibility = nil)
    create_response(canned_response_sample_params(folder_id, visibility))
  end

  def ca_responses_pattern(folder)
    {
      id: folder.id,
      name: folder.display_name,
      responses: responses_listing_pattern(folder.id)
    }
  end

  def responses_listing_pattern(folder_id)
    (fetch_ca_responses_from_db(folder_id) || []).map do |ca_response|
      ca_response.attributes.slice('id', 'title')
    end
  end

  def ca_folders_pattern
    (fetch_ca_folders_from_db || []).map do |folder|
      {
        id: folder.id,
        name: folder.display_name,
        personal: folder.personal?,
        responses_count: folder.visible_responses_count
      }
    end
  end

  def single_ca_response_pattern(ca_response)
    ca_response.attributes.slice('id', 'title')    
  end

  def fetch_ca_folders_from_db
    fetch_ca_responses_from_db
    folders = @ca_responses.map(&:folder)
    items = folders.uniq.sort_by { |folder| [folder.folder_type, folder.name] }
    items.each do |folder|
      folder.visible_responses_count = folders.count(folder)
    end
    items
  end

  def fetch_ca_responses(folder_id = nil)
    @ca_responses = accessible_from_es(Admin::CannedResponses::Response, { load: true, size: 300 }, default_visiblity, 'raw_title', folder_id)
    fetch_ca_responses_from_db(folder_id) if @ca_responses.nil?
    @ca_responses
  end

  def fetch_ca_responses_from_db(folder_id = nil)
    options = folder_id ? [{ folder_id: folder_id }] : [nil, [:folder]]
    @ca_responses = accessible_elements(@account.canned_responses, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', *options))
    @ca_responses.blank? ? @ca_responses : @ca_responses.compact!
    @ca_responses
  end

  def ca_response_show_pattern(ca_response_id = nil)
    ca_response = @account.canned_responses.find(ca_response_id)
    {
      id: ca_response.id,
      title: ca_response.title,
      content: ca_response.content,
      content_html: ca_response.content_html,
      folder_id: ca_response.folder_id
    }
  end

end