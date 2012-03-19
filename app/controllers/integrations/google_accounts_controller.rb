class Integrations::GoogleAccountsController < Admin::AdminController
  include Integrations::GoogleContactsUtil

  before_filter :update_params, :only => [:edit, :update]

  def edit
    Rails.logger.debug "Integrations::GoogleAccountsController.edit #{params.inspect}"
    @google_account = Integrations::GoogleAccount.find(:first, :conditions => ["id=? and account_id=?", params[:id], current_account])
    if(@google_account.blank?)
      flash[:error] = t('integrations.google_contacts.account_not_configured')
    else
      @google_groups = @google_account.fetch_all_google_groups
      @omniauth_origin = "edit_app"
    end
  end

  def update
    Rails.logger.debug "Integrations::GoogleAccountController.update #{params.inspect}"
    begin
      params[:enable_integration] = "true"
      goog_acc = handle_contacts_import params
      unless goog_acc.blank?
        flash[:notice] = "#{t('integrations.google_contacts.update_action.success')} #{flash[:notice].blank? ? "" : t('integrations.google_contacts.update_action.also') + flash[:notice]}"
      end
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
    Rails.logger.debug "Integrations::GoogleAccountsController.delete #{params.inspect}"
    begin
      Integrations::GoogleAccount.destroy_all ["id=? and account_id=?", params[:id], current_account]
      flash[:notice] = t('integrations.google_contacts.delete_action.success')
    rescue => err
        Rails.logger.error("Error during delete. \n#{err.message}\n#{err.backtrace.join("\n")}")
      flash[:error] = t('integrations.google_contacts.delete_action.error')
    end
    redirect_to configure_integrations_installed_application_path(params[:iapp_id])
  end

  def import_contacts
    handle_contacts_import params
    redirect_to :controller=> '/contacts'
  end

  private
    def handle_contacts_import(params, goog_acc=nil)
      goog_acc = Integrations::GoogleAccount.find_or_create(params, current_account) if goog_acc.blank?
      Rails.logger.debug "handle_contacts_import #{goog_acc.inspect}"
      if goog_acc.blank?
        Rails.logger.error "ERROR:: Google account not configured properly for importing."
        flash[:error] = t("integrations.google_contacts.internal_error")
      else
        begin
          add_group params, goog_acc # In case the group name passed does not have an id, add it first.
          # Save the google account before starting the importer.  So that importer will assume the google account as primary/synced google account.
          if !params[:enable_integration].blank? and (params[:enable_integration] == "true" || params[:enable_integration] == "1")
            enable_integration(goog_acc)
          end
          schedule_or_import_contacts params, goog_acc
          return goog_acc
        rescue Exception => e
          Rails.logger.error "Problem in importing google contacts for #{goog_acc.inspect}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          flash[:error] = t("integrations.google_contacts.import_problem")
        end
      end
      return nil
    end

    def add_group(params, goog_acc)
      g_id = params[:integrations_google_account][:sync_group_id]
      g_name = params[:integrations_google_account][:sync_group_name]
      if g_id.blank?
        g_id = goog_acc.create_google_group(g_name)
        goog_acc.sync_group_id = g_id
      end
    end

    def schedule_or_import_contacts(params, goog_acc)
      unless goog_acc.import_groups.blank?
        pre_import_groups = goog_acc.import_groups.clone
        latest_goog_cnts = goog_acc.fetch_latest_google_contacts(20)
        # Reset the start index and import groups so the real import happens from the beginning.
        goog_acc.reset_start_index
        goog_acc.import_groups = pre_import_groups
        goog_acc.donot_update_sync_time = true
        # Now start the importing.
        goog_cnts_iptr = Integrations::GoogleContactsImporter.new(goog_acc)
        if latest_goog_cnts.length > 20
          goog_acc.account = nil; goog_acc.account_id = current_account.id;  # This is needed because sometimes the to_yaml of account object (called by send_later for serializing into DB) fails due to some anonymous variables populated in the current_account object.  Also in a way this is little efficient for to_yaml. 
          # If more than 20 google contacts available for import add it to delayed jobs.
          user_email = current_user.email
          goog_cnts_iptr.send_later(:import_google_contacts, {:send_email=>true, :email=>user_email, :domain=>current_account.full_domain})
          flash[:notice] = t("integrations.google_contacts.import_later_success", :email => user_email)
        else
          updated_goog_acc = goog_cnts_iptr.import_google_contacts
          if updated_goog_acc.last_sync_status[:status] == "error"
            flash[:error] = t("integrations.google_contacts.import_problem")
          else
            db_stats = updated_goog_acc.last_sync_status[:db_stats]
            flash[:notice] = t("integrations.google_contacts.import_success_no_stats")
            # if db_stats.blank?
            #   flash[:notice] = t("integrations.google_contacts.import_success_no_stats")
            # else
            #   flash[:notice] = t("integrations.google_contacts.import_success", {:added=>(db_stats[0][0] ? db_stats[0][0] : 0), 
            #                           :updated=>(db_stats[0][1] ? db_stats[0][1] : 0), :deleted=>(db_stats[0][2] ? db_stats[0][2] : 0)})
            # end
          end
        end
      end
    end

    def update_params
      unless params["integrations_google_account"].blank?
        if params["integrations_google_account"]["overwrite_existing_user"].blank?
          params["integrations_google_account"]["overwrite_existing_user"] = false
        end
      end
    end
end
