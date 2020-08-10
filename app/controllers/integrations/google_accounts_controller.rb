class Integrations::GoogleAccountsController < Admin::AdminController
  include Integrations::GoogleContactsUtil
  include Integrations::Constants

  before_filter :update_params, :only => [:edit, :update]

  def new
    key_options = { :account_id => @current_account.id, :provider => "google_contacts"}
    kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
    kv_store.group = :integration
    app_config = kv_store.get_key
    config_hash = JSON.parse(app_config)
    user_info = config_hash['info']
    unless user_info.blank?
      if config_hash['origin'].blank? || config_hash['origin'].include?("integrations") 
        Rails.logger.error "The session variable to omniauth is not preserved or not set properly."
        @omniauth_origin = "install"
      end
      @google_account = Integrations::GoogleAccount.new
      @db_google_account = Integrations::GoogleAccount.find_by_account_id_and_email(@current_account, user_info["email"])
      if !@db_google_account.blank? && @omniauth_origin == "install"
        Rails.logger.error "As already an account has been configured can not configure one more account."
        flash[:error] = t("integrations.google_contacts.already_exist")
        
        redirect_to edit_integrations_installed_application_path(get_installed_app) and return
      else
        @existing_google_accounts = Integrations::GoogleAccount.where(account_id: @current_account)
        @google_account.account = @current_account #should it be account object or account.id ?
        @google_account.token = config_hash['oauth_token']
        @google_account.secret = config_hash['refresh_token']
        @google_account.name = user_info["name"]
        @google_account.email = user_info["email"]
        @google_account.sync_group_name = "Freshdesk Contacts"
        Rails.logger.debug "@google_account details #{@google_account.inspect} existing_google_accounts #{@existing_google_accounts.inspect}"
        @google_groups = @google_account.fetch_all_google_groups(nil, use_oauth2=true)
        # Reuse the group id, if the group with same name already exist.
        @google_groups.each { |g_group|
          @google_account.sync_group_id = g_group.group_id if g_group.name == @google_account.sync_group_name
        }
      end
    end
  end

  def update
    begin
      params[:enable_integration] = "true"
      goog_acc = handle_contacts_import(params, nil, use_oauth2=true)
      unless goog_acc.blank?
        flash[:notice] = "#{t('integrations.google_contacts.update_action.success')} #{flash[:notice].blank? ? "" : t('integrations.google_contacts.update_action.also') + flash[:notice]}"
      end
    rescue => err
      Rails.logger.error("Error during update. \n#{err.message}\n#{err.backtrace.join("\n")}")
      flash[:error] = t('integrations.google_contacts.update_action.error')
    end
    installed_app = get_installed_app
    if installed_app.blank?
      redirect_to :controller=> 'applications', :action => 'index'
    else
      redirect_to edit_integrations_installed_application_path(installed_app.id)
    end
  end

  def delete
    begin
      remove_installed_app_config(params[:id].to_i)
      Integrations::GoogleAccount.destroy_all ["id=? and account_id=?", params[:id].to_i, current_account.id]
      flash[:notice] = t('integrations.google_contacts.delete_action.success')
    rescue => err
        Rails.logger.error("Error during delete. \n#{err.message}\n#{err.backtrace.join("\n")}")
      flash[:error] = t('integrations.google_contacts.delete_action.error')
    end
    redirect_to edit_integrations_installed_application_path(get_installed_app)
  end

  private
    def handle_contacts_import(params, goog_acc=nil, use_oauth2=nil)
      goog_acc = Integrations::GoogleAccount.find_or_create(params, current_account) if goog_acc.blank?
      Rails.logger.debug "handle_contacts_import #{goog_acc.inspect}"
      if goog_acc.blank?
        Rails.logger.error "ERROR:: Google account not configured properly for importing."
        flash[:error] = t("integrations.google_contacts.internal_error")
      else
        begin
          add_group(params, goog_acc, use_oauth2) # In case the group name passed does not have an id, add it first.
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

    def add_group(params, goog_acc, use_oauth2=nil)
      g_id = params[:integrations_google_account][:sync_group_id]
      g_name = params[:integrations_google_account][:sync_group_name]
      if g_id.blank?
        g_id = goog_acc.create_google_group(g_name, use_oauth2) 
        goog_acc.sync_group_id = g_id
      end
    end

    def schedule_or_import_contacts(params, goog_acc)
      unless goog_acc.import_groups.blank?
        pre_import_groups = goog_acc.import_groups.clone
        latest_goog_cnts = goog_acc.fetch_latest_google_contacts(20,SyncType::IMPORT_EXPORT)
        goog_acc.reset_start_index # Reset the start index and import groups so the real import happens from the beginning.
        goog_acc.import_groups = pre_import_groups
        goog_acc.donot_update_sync_time = true
        goog_acc.access_token = nil # Removing. Because some case accesstoken reponse happens to be very big and makes its hard to fit within delayed_jobs column size.
        # Now start the importing.
        goog_cnts_iptr = Integrations::GoogleContactsImporter.new(goog_acc)
        if latest_goog_cnts.length > 20
          goog_acc.account = nil; goog_acc.account_id = current_account.id;  # This is needed because sometimes the to_yaml of account object (called by send_later for serializing into DB) fails due to some anonymous variables populated in the current_account object.  Also in a way this is little efficient for to_yaml. 
          # If more than 20 google contacts available for import add it to delayed jobs.
          user_email = current_user.email
          goog_cnts_iptr.send_later(:import_google_contacts, {:send_email=>true, :email=>user_email, :domain=>current_account.full_domain, :group_ids => params["integrations_google_account"]["import_groups"]})
          flash[:notice] = t("integrations.google_contacts.import_later_success", :email => user_email)
        else
          updated_goog_acc = goog_cnts_iptr.import_google_contacts({:group_ids => params["integrations_google_account"]["import_groups"]})
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

    def get_installed_app
      @current_account.installed_applications.with_name(APP_NAMES[:google_contacts]).first
    end
end
