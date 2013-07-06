class Support::Solutions::FoldersController < SupportController
	before_filter :scoper, :check_folder_permission

	def show
    	respond_to do |format|
        	format.html { 
        		@page_canonical = support_solutions_folder_url(@folder)
        		set_portal_page :article_list}
        	format.xml  { render :xml => @folder.to_xml(:include => :published_articles)}
        	format.json { render :json => @folder.as_json(:include => :published_articles)}
     	end
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