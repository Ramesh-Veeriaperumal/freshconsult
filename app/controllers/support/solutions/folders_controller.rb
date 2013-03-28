class Support::Solutions::FoldersController < SupportController
	before_filter :scoper, :check_folder_permission
 	before_filter :only => :show do |c|
		c.send(:set_portal_page, :article_list)
	end

	private
		def scoper
			@folder = current_account.folders.find_by_id(params[:id])
			(raise ActiveRecord::RecordNotFound and return) if @folder.nil?

			@category = @folder.category
		end

		def check_folder_permission			
	    	return redirect_to support_solutions_path if !@folder.nil? and !@folder.visible?(current_user)	    	
	  	end
end