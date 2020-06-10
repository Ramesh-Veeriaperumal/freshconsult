class Admin::DataExportController < Admin::AdminController
  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :check_export_status, :only => :export
  before_filter :load_data_export_item, :only => :download

  def check_export_status
    @data_export = current_account.data_exports.data_backup[0]
    if @data_export
      if @data_export.completed? || @data_export.failed?
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
    Export::DataExport.perform_async(params)
    flash[:notice] = t("export_data_successfull")
    redirect_to account_url #admin_data_export_index_url
  end

  def download
    file_url = if @item.ticket_export? && @item.job_id
                 check_download_permission
                 response = Silkroad::Export::Base.new.get_job_status(@item.job_id)
                 response['output_path']
               else
                 attachment = @item.attachment
                 helpdesk_attachment_path(attachment)
               end
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

    def check_download_permission
      access_denied unless privilege?(:manage_account) || @item.owner?(current_user)
    end
end
