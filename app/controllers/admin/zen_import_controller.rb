class Admin::ZenImportController < Admin::AdminController
  
before_filter { |c| c.requires_permission :manage_tickets }  


  def index  
    @import_status = current_account.data_import
  end
  
  def import_data
    
    @item = current_account.build_data_import({:status=>true , :import_type =>'Zendesk'})
    
    if @item.save
       @item.attachments.create(:content => params[:zendesk][:file], :description => 'zen data', :account_id => @item.account_id)
       handle_zen_import
       flash[:notice] =  t(:'flash.data_import.zendesk.success')
       redirect_to  admin_home_index_url
    else
      flash[:notice] = t(:'flash.data_import.zendesk.failure')
      redirect_to :index
    end

  end
  
  def handle_zen_import 
    zen_params = {:domain =>current_account.full_domain,
                  :email => current_user.email,
                  :zendesk =>{:url => params[:zendesk][:url], 
                              :user_name => params[:zendesk][:user_name],
                              :user_pwd => params[:zendesk][:user_pwd],
                              :files => params[:import][:files]
                              }
                  }
   
    Delayed::Job.enqueue Import::ZendeskData.new(zen_params)
  end
end
