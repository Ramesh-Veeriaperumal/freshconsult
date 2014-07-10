module CannedResponsesHelper

	def create_response(params = {})
	    test_response= Factory.build(:admin_canned_responses, :title => params[:title],:content_html => params[:content_html],
	       :visibility => {:user_id => params[:user_id], :visibility => params[:visibility], :group_id => params[:group_id]}, 
	       :folder_id => params[:folder_id])
	    test_response.account_id = Account.first.id
	    test_response.save(false)
	    test_response
    end

    def create_cr_folder(params = {})
    	test_cr_folder = Factory.build(:ca_folders, :name => params[:name])
    	test_cr_folder.account_id = Account.first.id
	    test_cr_folder.save(false)
	    test_cr_folder
    end
end