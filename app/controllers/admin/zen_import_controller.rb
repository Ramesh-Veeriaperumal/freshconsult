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
    params[:domain] =  current_account.full_domain
    params[:email] = current_user.email
    Delayed::Job.enqueue Import::ZendeskData.new(params)
  end
end
