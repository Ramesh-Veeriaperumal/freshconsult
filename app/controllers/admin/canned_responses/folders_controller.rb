class Admin::CannedResponses::FoldersController < Admin::AdminController

  before_filter :load_object, :only => [:update, :edit, :show, :destroy]
  before_filter :check_default, :only => [:edit, :destroy, :update]

  def index
    @ca_res_folders = scoper.all
    @ca_res_folder = @ca_res_folders.first
    @ca_responses = @ca_res_folder.canned_responses
    render :index
  end

  def show
    @ca_responses = @ca_res_folder.canned_responses
    respond_to do |format|
      format.html { 
        if request.headers['X-PJAX']
          render :partial => 'show'
        else
          @ca_res_folders = scoper.all
          render :index
        end 
      }
      format.js
    end
  end

  def new
  	@ca_res_folder = scoper.new
    	respond_to do |format|
      	format.html { 
          if request.xhr?
            render :layout => false
          else
            redirect_to admin_canned_responses_folders_path
          end 
        }
      	format.xml  { render :xml => @ca_res_folder }
      end
  end

  def create    
  	@ca_res_folder = scoper.build(params[nscname])
  	respond_to do |format|
      if @ca_res_folder.save        
      	format.html {
          redirect_to(admin_canned_responses_folder_path(@ca_res_folder), 
          :notice => t('canned_folders.folder_created'))
        }        
      	format.xml  { render :xml => @ca_res_folder, 
          :status => :created, 
          :location => @ca_res_folder }
      else
    		format.html { render :action => "new" }
    		format.xml  { render :xml => @ca_res_folder.errors, 
          :status => :unprocessable_entity }
      end
  	end
  end

  def edit
    respond_to do |format|
  		format.html  # edit.html.erb 
  		format.xml  { render :xml => @ca_res_folder }
    end
  end

  def update
  	respond_to do |format|
      if @ca_res_folder.update_attributes(params[nscname])
  		  format.html {
          redirect_to(admin_canned_responses_folder_path(@ca_res_folder) ,
          :notice => t('canned_folders.updated'))
        }
    	  format.xml  { head :ok }
      else
        format.html {
          redirect_to(admin_canned_responses_folder_path(@ca_res_folder) ,
          :notice => @ca_res_folder.errors.full_messages.to_s)
        }
      end
  	end
  end

  def destroy 
  	@ca_res_folder.destroy
  	respond_to do |format|
    		format.html { redirect_to(admin_canned_responses_folders_path ,
                      :notice => t('canned_folders.deleted')) }
    		format.xml  { head :ok }
  	end
  end

  private

    def scoper
    	current_account.canned_response_folders
    end

    def cname
      @cname ||= controller_name.singularize
    end

    def nscname
      @nscname ||= controller_path.gsub('/', '_').singularize
    end

    def load_object
      @ca_res_folder = scoper.find(params[:id])
    end

    def check_default
      if @ca_res_folder.is_default?
          raise t('canned_folders.no_edit')
      end
    end
end
