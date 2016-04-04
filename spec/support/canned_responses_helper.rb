module CannedResponsesHelper

  def create_response(params = {})
    group = create_group(@account, {:name => "Response"})
    folder_id = @account.canned_response_folders.default_folder.last.id
    response_hash = {
                      :title => params[:title],
                      :content_html => params[:content_html],
                      :visibility => {  "user_id" => params[:user_id] || @agent.id,
                                        "visibility" => params[:visibility],
                                        "group_id" => group.id },
                      :folder_id => params[:folder_id] || folder_id
                    }
    test_response= FactoryGirl.build(:admin_canned_responses, response_hash)
    test_response.account_id = @account.id
    if params[:attachments]
      test_response.shared_attachments.build.build_attachment(:content => params[:attachments][:resource],
                                                              :description => params[:attachments][:description],
                                                              :account_id => test_response.account_id)
    end
    test_response.save(:validate => false)
    create_helpdesk_accessible(test_response,response_hash[:visibility])
    test_response
  end

  def create_cr_folder(params = {})
    test_cr_folder = FactoryGirl.build(:ca_folders, :name => params[:name])
    test_cr_folder.account_id = @account.id
    test_cr_folder.save(:validate => false)
    test_cr_folder
  end

  def create_helpdesk_accessible(item,visibility)
    return if item.helpdesk_accessible
      visible_type_id,visible_type_str  = map_new_visible_type(visibility)
      accessible = item.create_helpdesk_accessible(:access_type => visible_type_id)
      if visible_type_id != Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
        accessible_ids = [*visibility["#{visible_type_str}_id"]]
        accessible.send("create_#{visible_type_str}_accesses",accessible_ids)
      end
  end

  def map_new_visible_type(visibility) 
    case visibility["visibility"].to_i 
      when Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
        new_visible_type_id = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:groups]
      when Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
        new_visible_type_id = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
      when Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]
        new_visible_type_id = Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:users]
    end
    return new_visible_type_id, Helpdesk::Access::ACCESS_TYPES_KEYS[new_visible_type_id]
  end
end
