class Integrations::GoogleAccountsController < Admin::AdminController
  include Integrations::GoogleContactsUtil

  def edit
    puts "Integrations::GoogleAccountsController.edit #{params.inspect}"
    @google_account = Integrations::GoogleAccount.find(:first, :conditions => ["id=? and account_id=?", params[:id], current_account])
    if(@google_account.blank?)
      flash[:error] = t('integrations.google_contacts.account_not_configured')
    else
      @google_groups = @google_account.fetch_all_google_groups
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
        goog_acc.account = nil; goog_acc.account_id = current_account.id;  # This is needed because sometimes the to_yaml of account object (called by send_later for serializing into DB) fails due to some anonymous variables populated in the current_account object.  Also in a way this is little efficient for to_yaml. 
        # Save the google account before starting the importer.  So that importer will assume the google account as primary/synced google account.
        if !params[:enable_integration].blank? and (params[:enable_integration] == "true" || params[:enable_integration] == "1")
          enable_integration
        else
          goog_acc.make_it_non_primary # In case the account is already saved.
        end
        user_email = current_user.email
        latest_goog_cnts = goog_acc.fetch_latest_google_contacts(nil, nil, 21)
        if latest_goog_cnts.length > 20
          # If more than 20 google contacts available for import add it to delayed jobs.
          Integrations::GoogleContactsImporter.new(goog_acc).send_later(:import_google_contacts, {:send_email=>true, :email=>user_email, :domain=>current_account.full_domain})
          flash[:notice] = t("integrations.google_contacts.import_later_success", :email => user_email)
        else
          goog_cnts_iptr = Integrations::GoogleContactsImporter.new(goog_acc)
          updated_goog_acc = goog_cnts_iptr.import_google_contacts
          puts "status #{updated_goog_acc.last_sync_status.inspect}"
          if updated_goog_acc.last_sync_status[:status] == "error"
            flash[:error] = t("integrations.google_contacts.import_problem")
          else
            db_stats = updated_goog_acc.last_sync_status[:db_stats]
            if db_stats.blank?
              flash[:notice] = t("integrations.google_contacts.import_success_no_stats")
            else
              flash[:notice] = t("integrations.google_contacts.import_success", {:added=>(db_stats[0][0] ? db_stats[0][0] : 0), 
                                      :updated=>(db_stats[0][1] ? db_stats[0][1] : 0), :deleted=>(db_stats[0][2] ? db_stats[0][2] : 0)})
            end
          end
        end
      rescue Exception => e
        puts "Problem in importing google contacts for #{goog_acc.inspect}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        flash[:error] = t("integrations.google_contacts.import_problem")
      end
    end
    redirect_to :controller=> '/contacts'
  end
end
