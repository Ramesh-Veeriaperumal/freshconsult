class Admin::ZenImportController < Admin::AdminController
  

before_filter :check_zendesk_import_status, :only => :index

  def index  
    
  end
  
  def import_data
    
    @item = current_account.build_zendesk_import({:status=>true })   
    if @item.save
       handle_zen_import
       flash[:notice] =  t(:'flash.data_import.zendesk.success')
       redirect_to  admin_home_index_url
    else
      flash[:notice] = t(:'flash.data_import.zendesk.failure')
      redirect_to :index
    end

  end
  
  def handle_zen_import 
    zen_params = {:account_id => current_account.id,
                  :domain =>current_account.full_domain,
                  :email => current_user.email,
                  :zendesk =>{:url => params[:zendesk][:url], 
                              :user_name => params[:zendesk][:user_name],
                              :user_pwd => params[:zendesk][:user_pwd],
                              :files => params[:import][:files],
                              :file_url => params[:zendesk][:file_url]
                              }
                  }
   
    #Delayed::Job.enqueue Import::Zen::Start.new(zen_params)
    Resque.enqueue( Import::Zen::ZendeskImport,zen_params)
  end
  
  protected
  
  def check_zendesk_import_status
   @import_status = current_account.zendesk_import
   if  @import_status && @import_status.status
     flash[:notice] = t(:'flash.data_import.zendesk.running') 
     redirect_to  admin_home_index_url
   end
  end
end
