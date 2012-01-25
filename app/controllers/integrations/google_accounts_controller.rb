class Integrations::GoogleAccountsController < Admin::AdminController
  include Integrations::GoogleContactsUtil

  def edit
    puts "Integrations::GoogleAccountsController.edit #{params.inspect}"
    @google_account = Integrations::GoogleAccount.find(:first, :conditions => ["id=? and account_id=?", params[:id], current_account])
    if(@google_account.blank?)
      flash[:error] = t('integrations.google_contacts.account_not_configured')
    else
      @google_groups = @google_account.find_all_google_groups
      @omniauth_origin = "edit_app"
    end
  end

  def update
    puts "Integrations::GoogleAccountController.update #{params.inspect}"
    begin
      goog_acc = Integrations::GoogleAccount.find_or_create(params, current_account)
      goog_acc.save!
      flash[:notice] = t('integrations.google_contacts.update_action.success')
    rescue => err
      Rails.logger.error("Error during update. \n#{err.message}\n#{err.backtrace.join("\n")}")
      flash[:error] = t('integrations.google_contacts.update_action.error')
    end
    if params[:iapp_id].blank?
      redirect_to :controller=> 'applications', :action => 'index'
    else
      redirect_to configure_integrations_installed_application_path(params[:iapp_id]) 
    end
  end

  def delete
    puts "Integrations::GoogleAccountsController.delete #{params.inspect}"
    begin
      Integrations::GoogleAccount.delete_all ["id=? and account_id=?", params[:id], current_account]
      flash[:notice] = t('integrations.google_contacts.delete_action.success')
    rescue => err
        Rails.logger.error("Error during delete. \n#{err.message}\n#{err.backtrace.join("\n")}")
      flash[:error] = t('integrations.google_contacts.delete_action.error')
    end
    redirect_to configure_integrations_installed_application_path(params[:iapp_id])
  end

  def import_contacts
    puts "import_contacts #{params.inspect}"
    goog_acc = Integrations::GoogleAccount.find_or_create(params, current_account)
    if goog_acc.blank?
      puts "ERROR:: Google account not configured properly for importing."
      flash[:error] = t("integrations.google_contacts.internal_error")
    else
      begin
        sync_tag = goog_acc.sync_tag
        unless sync_tag.blank?
          goog_acc.sync_tag = sync_tag.save! if sync_tag.id.blank? # Create the tag only if the id is not null, which means it does not exist in the DB.
        end
        goog_acc.account = nil; goog_acc.account_id = current_account.id;  # This is needed because sometimes the to_yaml of account object (called by send_later for serializing into DB) fails due to some anonymous variables populated in the current_account object.  Also in a way this is little efficient. 
        Integrations::GoogleContactsImporter.new(goog_acc).send_later(:import_google_contacts)
        # TODO.  Do not overwrite the google_id when multiple account imported.  Only schedule more than 25 contacts.  Send email after finishing import.  Maintain the sync status.
        if !params[:enable_integration].blank? and (params[:enable_integration] == "true" || params[:enable_integration] == "1")
          goog_acc.save!
        end
        flash[:notice] = t("integrations.google_contacts.import_success")
      rescue Exception => e
        puts "Problem in importing google contacts for #{goog_acc.inspect}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        flash[:error] = t("integrations.google_contacts.import_problem")
      end
    end
    redirect_to :controller=> '/contacts'
  end
end
