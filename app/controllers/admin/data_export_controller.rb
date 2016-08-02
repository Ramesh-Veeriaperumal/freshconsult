class Admin::DataExportController < Admin::AdminController
  
  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :check_export_status, :only => :export
  before_filter :load_data_export_item, :only => :download

  def check_export_status
    @data_export = current_account.data_exports.data_backup[0]
    if @data_export 
      if @data_export.completed?
        @data_export.destroy
      else
        flash[:notice] = t("export_data_running")
        return redirect_to(account_url)
      end
    end
    @data_export = current_account.data_exports.new(
                                                    :user => current_user,
                                                    :source => DataExport::EXPORT_TYPE[:backup]
                                                    )
    @data_export.save
  end

  def index
  end

  def export
    params[:domain] =  current_account.full_domain
    params[:email] = current_user.email
    if redis_key_exists?(ACCOUNT_EXPORT_SIDEKIQ_ENABLED)
      Export::DataExport.perform_async(params)
    else
      Resque.enqueue(Helpdesk::ExportData, params)
    end
    flash[:notice] = t("export_data_successfull")
    redirect_to account_url #admin_data_export_index_url
  end

  def download
    attachment = @item.attachment
    file_url = helpdesk_attachment_path(attachment)
    redirect_to file_url  
  end

  protected

    def load_data_export_item
      @item = current_account.data_exports.find_by_source_and_token(params[:source], params[:token])
      if @item.nil?
        flash[:notice] = t("export_file_not_available")
        redirect_to support_home_url
      end
    end

end