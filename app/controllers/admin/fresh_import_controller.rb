class Admin::FreshImportController < Admin::AdminController
  include FreshImport::Jobs

  def index
    @vendor_chosen = session[:vendor_chosen]
    @selected_vendor = session[:selected_vendor]
    exporter_url = "http://localhost:3001/"
    @import_in_progress = false
    @session_names = []
    begin
        response =  JSON.parse((RestClient.get "#{exporter_url}session_running", {:params => {:account_id => current_account.id}}), :symbolize_names => true)
        @import_in_progress = response[:session_running]
        response =  JSON.parse((RestClient.get "#{exporter_url}sessions", {:params => {:account_id => current_account.id}}), :symbolize_names => true)
        @session_names = response[:sessions]
    rescue StandardError
    end
    session[:vendor_chosen] = false
  end

  def select_vendor
    session[:vendor_chosen] = true
    session[:selected_vendor] = @selected_vendor = params[:vendor][:name]
    if @selected_vendor == "Zendesk" then
      session[:vendor_chosen] = false
      redirect_to admin_zen_import_index_url
    else
      redirect_to admin_fresh_import_index_url
    end
  end

  def export_kayako
    params[:kayako][:tickets] = params[:tickets] == "1" ? true : false
    params[:kayako][:attachments] = params[:attachments] == "1" ? true : false
    params[:kayako][:knowledgebase] = params[:knowledgebase] == "1" ? true : false
    FreshImport::Jobs::Kayako.queue params[:kayako]
    redirect_to admin_fresh_import_index_url
  end

  def export_desk
    params[:desk][:tickets] = params[:tickets] == "1" ? true : false
    params[:desk][:attachments] = params[:attachments] == "1" ? true : false
    params[:desk][:knowledgebase] = params[:knowledgebase] == "1" ? true : false
    FreshImport::Jobs::ServiceDesk.queue params[:desk]
    redirect_to admin_fresh_import_index_url
  end

  def import_freshdesk
    FreshImport::Jobs::FreshDesk.queue params
    redirect_to admin_fresh_import_index_url
  end
end
