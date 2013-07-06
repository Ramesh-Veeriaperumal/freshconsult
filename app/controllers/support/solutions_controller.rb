class Support::SolutionsController < SupportController
	before_filter :load_category, :only => :show
	before_filter { |c| c.check_portal_scope :open_solutions }

	def index
	   	respond_to do |format|
	    	format.html { 
         		@page_canonical = support_solutions_url
       	  		set_portal_page :solution_home}
        	format.xml {
          		load_customer_categories
          		render :xml => @categories.to_xml(:include=>:public_folders)}
        	format.json { 
          		load_customer_categories
          		render :json => @categories.to_json(:include=>:public_folders)}
        end  		
	end

	def show
		set_portal_page :solution_category
	end

	private
		def load_category
			@category = current_portal.main_portal ? current_portal.solution_categories.find_by_id(params[:id]) : 
				current_portal.solution_category

			(raise ActiveRecord::RecordNotFound and return) if @category.nil?
		end

		def load_customer_categories	
		    @categories=@current_portal.solution_categories.customer_categories.all(:include=>:public_folders)
	 	end

end