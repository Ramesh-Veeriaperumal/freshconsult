class Admin::CannedResponses::ResponsesController < Admin::AdminController
  include HelpdeskControllerMethods
  uses_tiny_mce :options => Helpdesk::TICKET_EDITOR

  before_filter :load_multiple_items, :only => [:delete_multiple, :update_folder]
  before_filter :load_all_folders, :only => [:new, :edit, :create]
  before_filter :load_folder, :only => [:new, :edit]

  def show
   	redirect_to edit_admin_canned_responses_folder_response_path
  end

	def new
		@ca_response = scoper.new
		@ca_response.accessible = current_account.user_accesses.new
		@ca_response.accessible.visibility = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
		respond_to do |format|
		  format.html
		  format.xml  { render :xml => @ca_response }
		end
	end

	def edit
		@ca_response = scoper.find(params[:id]) 
		  respond_to do |format|
		  format.html # edit.html.erb
		  format.xml  { render :xml => @ca_response }
		end
	end
  
	def create
		@folder = @ca_res_folders.select{|x| x.id == params[:new_folder_id].to_i}.first
		params[nscname].merge!("folder_id"=>params[:new_folder_id])
		@ca_response = scoper.build(params[nscname])
		respond_to do |format|
		  if @ca_response.save        
		    format.html {redirect_to(admin_canned_responses_folder_path(@folder), 
		      :notice => t('canned_folders.created')) }        
		    format.xml  { render :xml => @ca_response, 
		      :status => :created, 
		      :location => @ca_response }
		  else
				@ca_response.accessible = current_account.user_accesses.new
				@ca_response.accessible.visibility = params[:admin_canned_response][:visibility][:visibility]
				format.html { render :action => "new" }
				format.xml  { render :xml => @ca_response.errors, :status => :unprocessable_entity }
		  end
		end
	end

	def update
		@ca_response = scoper.find(params[:id]) 
		params[nscname].merge!("folder_id"=>params[:new_folder_id])   
		respond_to do |format|     
			if @ca_response.update_attributes(params[nscname])           
			  format.html {redirect_to(admin_canned_responses_folder_path(@ca_response.folder_id), 
			    :notice => t('canned_folders.update')) } 
			  format.xml  { render :xml => @ca_response, 
			    :status => :updated, :location => @ca_response }     
			else
			  format.html { render :action => "edit" }
			  format.xml  { render :xml => @ca_response.errors, 
			    :status => :unprocessable_entity }
			end
		end
	end

	def delete_multiple
		@items.each do |item|
			item.destroy
		end
	end

	def update_folder
		@resp_folder = current_account.canned_response_folders.find(params[:move_folder_id])
		@items.each do |item|
			item.update_attribute(:folder_id, params[:move_folder_id])
		end
		redirect_to(:back, 
			:notice => t('canned_folders.folder_update',{:folder_name => @resp_folder.name}))
	end

	private

		def scoper
	  	current_account.canned_responses
		end
	 
	  def cname
	    @cname ||= controller_name.singularize
	  end

	  def nscname
	    @nscname ||= controller_path.gsub('/', '_').singularize
	  end

	  def load_all_folders
	  	@ca_res_folders = current_account.canned_response_folders.all
	  end

	  def load_folder
	  	@folder = @ca_res_folders.select{|x| x.id == params[:folder_id].to_i}.first
	  end

	end
