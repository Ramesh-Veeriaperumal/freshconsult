class Support::Solutions::FoldersController < SupportController
	before_filter :scoper, :check_folder_permission
	before_filter { |c| c.check_portal_scope :open_solutions }
	
	def show
		@page_title = @folder.name
		respond_to do |format|
			format.html {
				load_agent_actions(solution_category_folder_path(@category, @folder), :view_solutions)
				load_page_meta
				set_portal_page :article_list
			}
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
    
    def load_page_meta
      @page_meta ||= {
        :title => @folder.name,
        :description => @folder.description,
        :canonical => support_solutions_folder_url(@folder, :host => current_portal.host)
      }
    end

		def check_folder_permission			
	    return redirect_to support_solutions_path if !@folder.nil? and !@folder.visible?(current_user)	    	
	  end
end