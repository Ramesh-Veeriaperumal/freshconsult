class ContactImportController < ApplicationController
   include Integrations::GoogleContactsUtil
   include Helpdesk::ToggleEmailNotification

   before_filter { |c| c.requires_permission :manage_tickets }
   before_filter :disable_user_activation
   after_filter :enable_notification
   map_fields :create, 
                    ['Name','Job Title','Company','Phone','Email','Twitter Id'], 
                    :file_field => :file, 
                    :params => [:user]
   
  
  def create
    if fields_mapped?
      contact_params = {:account => current_account,
                        :email => current_user.email,
                        :contacts =>{:mapped_fields => mapped_fields,
                                  :fields => params[:fields] ,
                                  :ignore_first_row => params[:ignore_first_row]}}

       Resque.enqueue(Import::Csv::ContactWorker ,contact_params)
       
       flash[:notice] = t(:'flash.import.success')
      redirect_to contacts_url
    else
      render
    end
  rescue MapFields::InconsistentStateError
    flash[:error] = t(:'flash.contacts_import.failure')
    redirect_to csv_contact_import_path
  rescue MapFields::MissingFileContentsError
    flash[:error] = t(:'flash.contacts_import.no_file')
    redirect_to csv_contact_import_path
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