class CustomersImportController < ApplicationController
   include Integrations::GoogleContactsUtil
   include Helpdesk::ToggleEmailNotification
   include ImportCsvUtil

   before_filter :disable_user_activation
   after_filter :enable_notification
   before_filter :map_fields, :only => :create
   after_filter :map_fields_cleanup, :only => :create

   #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def csv
    redirect_to "/#{params[:type].pluralize}", :flash => { :notice => t(:'flash.import.already_running')} if current_account.send("#{params[:type]}_import")
  end 
  
  def create
    if fields_mapped?
      params[:type].eql?("company") ? Resque.enqueue(Workers::Import::CompaniesImport, customer_params) : 
                  Resque.enqueue(Workers::Import::ContactsImport, customer_params)
      current_account.send(:"create_#{params[:type]}_import",{:status => 1})
      redirect_to "/#{params[:type].pluralize}", :flash =>{ :notice => t(:'flash.import.success')}
    else
      render
    end
    rescue CSVBridge::MalformedCSVError => e
      redirect_to "/customers_import/csv/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.wrong_format')}
    rescue ImportCsvUtil::InconsistentStateError
      redirect_to "/customers_import/csv/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.failure')}
    rescue ImportCsvUtil::MissingFileContentsError
      redirect_to "/customers_import/csv/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.no_file')}
    rescue ImportCsvUtil::OnlyHeaders
      redirect_to "/customers_import/csv/#{params[:type]}", :flash=>{:error => "Only headers are present..."}
  end

  def google
    puts params.inspect+". Importing google contacts for account "+current_account.inspect
    redirect_to "/auth/google?origin=import"
=begin
    @google_account = Integrations::GoogleAccount.find_by_account_id(current_account)
    use_existing_auth = params['use_existing_auth'] 
    # use_existing_auth is set from confirmation page. If use_existing_auth is not passed then the response will render confirmation page.
    if use_existing_auth.blank? or use_existing_auth == 'yes'
      if @google_account.blank? # Google account setting is never done before.
        redirect_to "/auth/google?origin=import"
      elsif use_existing_auth.blank? # Google account setting is already configured.  Ask for confirmation.
        render :layout=>false
      else # Google account setting is already configured and user choose use the same.  So forward him to import contact page.
        redirect_to :controller => "integrations/google_contacts", :action => "list_groups_contacts"
      end
    else # force google authentication even though the google accounts settings are already available.
        redirect_to "/auth/google?origin=import"
    end
=end
  end
end