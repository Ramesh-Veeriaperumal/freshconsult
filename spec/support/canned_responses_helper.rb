module CannedResponsesHelper

  def create_response(params = {})
    group = create_group(@account, {:name => "Response"})
    folder_id = @account.canned_response_folders.default_folder.last.id
    test_response= Factory.build(:admin_canned_responses, :title => params[:title],
                                 :content_html => params[:content_html],
                                 :visibility => {"user_id" => params[:user_id] || @agent.id,
                                                 "visibility" => params[:visibility],
                                                 "group_id" => group.id},
                                 :folder_id => params[:folder_id] || folder_id)
    test_response.account_id = @account.id
    if params[:attachments]
      test_response.shared_attachments.build.build_attachment(:content => params[:attachments][:resource],
                                                              :description => params[:attachments][:description],
                                                              :account_id => test_response.account_id)
    end
    test_response.save(false)
    test_response
  end

  def create_cr_folder(params = {})
    test_cr_folder = Factory.build(:ca_folders, :name => params[:name])
    test_cr_folder.account_id = @account.id
    test_cr_folder.save(false)
    test_cr_folder
  end
end
