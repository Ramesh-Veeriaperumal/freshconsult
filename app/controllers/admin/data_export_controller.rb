class Admin::DataExportController <  Admin::AdminController
 
  before_filter :check_export_status, :only => :export
  
  def check_export_status
    @data_export = current_account.data_export
    if @data_export.blank?
      @data_export = current_account.build_data_export(:status => true)
      @data_export.save!
    elsif @data_export.status
      flash[:notice] = "Data export will be sent to your mail shortly"
      return redirect_to(admin_data_export_index_url)
    end
  end
  
  
  def index
  end
 
  def export 
    params[:domain] =  current_user.full_domain
    params[:email] = current_user.email
    Delayed::Job.enqueue Helpdesk::ExportData.new(params)
    flash[:notice] = "Data export will be sent to your mail shortly"
    redirect_to admin_data_export_index_url
  end
  
  
end