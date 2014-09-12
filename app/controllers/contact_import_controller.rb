class ContactImportController < ApplicationController
   include Integrations::GoogleContactsUtil
   include Helpdesk::ToggleEmailNotification

   before_filter :disable_user_activation
   after_filter :enable_notification
   field_labels = [   I18n.t("contact_import.name"),
                      I18n.t("contact_import.job_title"),
                      I18n.t("contact_import.email"),
                      I18n.t("contact_import.work_phone"),
                      I18n.t("contact_import.mobile_phone"),
                      I18n.t("contact_import.twitter_id"),  
                      I18n.t("contact_import.company"),
                      I18n.t("contact_import.address"),
                      I18n.t("contact_import.tags"),                      
                      I18n.t("contact_import.background_info"),
                      I18n.t("contact_import.language"),
                      I18n.t("contact_import.timezone"),
                      I18n.t("contact_import.can_see_all_tickets_of_the_company") ]
                      
   map_fields :create, field_labels, 
                    :file_field => :file, 
                    :params => [:user]
   
  def csv
    redirect_to contacts_url, :flash => { :notice => t(:'flash.import.already_running')} if current_account.contact_import
  end 
  
  def create
    if fields_mapped?
        contact_params = {:account_id => current_account.id,
                        :email => current_user.email,
                        :contacts =>{:mapped_fields => mapped_fields,
                                  :fields => params[:fields] ,
                                  :ignore_first_row => params[:ignore_first_row]}}
         Resque.enqueue(Workers::Import::ContactsImport ,contact_params)
         current_account.create_contact_import({:status => 1})

         redirect_to contacts_url, :flash =>{ :notice => t(:'flash.import.success')}
    else
      render
    end
  rescue CSVBridge::MalformedCSVError => e
    redirect_to csv_contact_import_path, :flash => {:error => t(:'flash.contacts_import.wrong_format')}
  rescue MapFields::InconsistentStateError
    redirect_to csv_contact_import_path, :flash => {:error => t(:'flash.contacts_import.failure')}
  rescue MapFields::MissingFileContentsError
    redirect_to csv_contact_import_path, :flash => {:error => t(:'flash.contacts_import.no_file')}
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