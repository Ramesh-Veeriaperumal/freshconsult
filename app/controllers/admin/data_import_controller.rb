class Admin::DataImportController < Admin::AdminController
  
  before_filter :load_data_import_item

  def download
    attachment = @item.attachments.first
    file_url = helpdesk_attachment_path(attachment)
    redirect_to file_url  
  end

  protected

    def load_data_import_item
      @item = current_account.send(:"#{params[:type]}_import")
      if @item.nil?
        flash[:notice] = t("import_file_not_available")
        redirect_to support_home_url
      end
    end
end