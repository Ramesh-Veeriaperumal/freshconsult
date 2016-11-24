class Integrations::OutlookContactsController < Admin::AdminController
  include Integrations::OutlookContacts::Constant

  APP_NAME = Integrations::Constants::APP_NAMES[:outlook_contacts]

  before_filter :load_configs, :only => [:settings, :new, :install]
  before_filter :build_installed_application, :build_sync_account, :only => [:settings, :install]
  before_filter :fetch_metadata_fields, :only => [:new, :render_fields]
  before_filter :load_installed_application, :only => [:edit, :destroy, :render_fields, :update]
  before_filter :check_sync_accounts_limit, :only => [:install]
  after_filter :remove_configs, :only => [:install]

  def settings
    begin
      service_obj = IntegrationServices::Services::OutlookContactsService.new(@installed_application, nil, { "sync_account" => @sync_account })
      import_folders = service_obj.receive(:fetch_folders)
      import_folders.delete_if do |group|
        if group[:name] == FRESHDESK_FOLDER
          set_redis_keys(@configs.merge({ "fd_folder_id" => group[:id] }), 300)
          true
        end
      end
      import_folders.unshift({ :id => "--default-contacts--", :name => "Contacts" })
      form_params = {
        :url => '/integrations/outlook_contacts/new',
        :app_name => APP_NAME,
        :import_folders => import_folders,
        :sync_tag => APP_NAME
      }
      render :template => "integrations/applications/contacts_sync/settings", :locals => form_params and return
    rescue Exception => e
      Rails.logger.error "Problem in enabling outlook contacts sync. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id } })
      flash[:error] = @installed_application.new_record? ? t(:'flash.application.install.error') : t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end
  end

  def new
    begin
      set_redis_keys(@configs.merge({"contacts_sync" => params[:contacts_sync]}),300)
      @element_config['existing_contacts'] = MAPPED_FIELDS
      @element_config['enble_sync'] = 'on'
      @action = 'install'
      render :template => "integrations/applications/contacts_sync/sync", :locals => {:app_name => APP_NAME}
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => Account.current.id, :description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end
  end

  def install
    begin
      new_record = @installed_application.new_record?
      @installed_application.save! if new_record
      @sync_account.installed_application_id = @installed_application.id
      @sync_account.save!
      sync_contacts
      flash[:notice] = new_record ? t(:'flash.application.install.success') : t(:'flash.application.update.success')
      redirect_to integrations_applications_path
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:account_id => Account.current.id, :description => "Problem in installing the application : #{e.message}"}})
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end
  end

  def edit
    begin
      form_params = {
        :app_name => APP_NAME,
        :oauth_url => @application.oauth_url({:account_id => current_account.id, :portal_id => current_portal.id, :user_id => current_user.id}, @application[:name])
      }
      render :template => "integrations/applications/contacts_sync/edit", :locals => form_params and return
    rescue Exception => e
      Rails.logger.error "Problem in rendering outlook contacts sync edit form. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id } })
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_applications_path
    end
  end

  def update
    begin
      sync_account = @installed_application.sync_accounts.find(params[:id])
      sync_account.configs['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
      sync_account.active = params[:enble_sync] == 'on'
      sync_account.save!
      flash[:notice] = t(:'flash.application.update.success')
      redirect_to integrations_outlook_contacts_edit_path
    rescue => e
      Rails.logger.error "Problem in enabling outlook contacts sync. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id } })
      flash[:error] = t(:'flash.application.update.error')
      redirect_to integrations_outlook_contacts_edit_path
    end
  end

  def destroy
    begin
      @installed_application.sync_accounts.find(params[:id]).destroy
      flash[:notice] = t("integrations.outlook_contacts.delete_action.success")
      redirect_to integrations_outlook_contacts_edit_path
    rescue Exception => e
      Rails.logger.error "Problem in deleting account - outlook contacts sync. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id, :params => params.to_json } })
      flash[:error] = t("integrations.outlook_contacts.delete_action.error")
      redirect_to integrations_outlook_contacts_edit_path
    end
  end

  def render_fields
    sync_account = @installed_application.sync_accounts.find(params[:id])
    unless sync_account.last_sync_status == 'in_progress'
      construct_synced_contacts(sync_account)
      @element_config['enble_sync'] = 'on' if sync_account.active
      @action = 'update'
      render :template => "integrations/applications/contacts_sync/sync", :locals => {:app_name => APP_NAME}
    else
      flash[:error] = t("integrations.outlook_contacts.sync_settings.progress")
      redirect_to integrations_outlook_contacts_edit_path
    end
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application : #{e.message}"}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_outlook_contacts_edit_path
  end

  private

    def load_configs
      begin
        @configs = JSON.parse(generate_redis_key.get_key)
      rescue Exception => e
        Rails.logger.error "Error while loading #{}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id } })
        flash[:error] = t(:'flash.application.update.error')
        redirect_to integrations_applications_path
      end
    end

    def remove_configs
      generate_redis_key.remove_key
    end

    def build_installed_application
      @installed_application = current_account.installed_applications.find_by_application_id(application)
      if @installed_application.blank?
        @installed_application = current_account.installed_applications.build(:application => application)
        @installed_application.configs = { :inputs => {} }
      end
    end

    def load_installed_application
      @installed_application = current_account.installed_applications.find_by_application_id(application)
      if @installed_application.blank?
        flash[:error] = t(:'flash.application.update.error')
        redirect_to integrations_applications_path and return
      end
    end

    def application
      @application = Integrations::Application.find_by_name(APP_NAME)
    end

    def build_sync_account
      @sync_account = Integrations::SyncAccount.new
      @sync_account.account = Account.current
      @sync_account.name = @configs['name']
      @sync_account.email = @configs['unique_name']
      @sync_account.oauth_token = @configs['oauth_token']
      @sync_account.refresh_token = @configs['refresh_token']
      @sync_account.sync_group_name = @configs['fd_folder_name']
      @sync_account.sync_group_id = @configs['fd_folder_id']
      if @configs['contacts_sync'].present?
        sync_tag_name = @configs['contacts_sync']['sync_tag']
        if sync_tag_name.present?
          sync_tag = Account.current.tags.find_or_create_by_name(sync_tag_name)
          @sync_account.sync_tag_id = sync_tag.id
        end
        @sync_account.overwrite_existing_user = @configs['contacts_sync']['overwrite_existing_user']
        @sync_account.configs['contacts'] = get_selected_field_arrays(params[:inputs][:contacts])
        @sync_account.active = true
      end
    end

    def check_sync_accounts_limit
      if @installed_application.sync_accounts.length == Integrations::Constants::CONTACTS_SYNC_ACCOUNTS_LIMIT
        flash[:error] = t(:'flash.application.update.error')
        redirect_to integrations_applications_path
      end
    end

    def set_redis_keys(config_params, expire_time = nil)
      key_options = { :account_id => current_account.id, :provider => APP_NAME }
      key_spec = Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
      Redis::KeyValueStore.new(key_spec, config_params.to_json, {:group => :integration, :expire => expire_time || 300}).set_key
    end

    def sync_contacts
      begin
        import_folders = []
        import_folders = @configs['contacts_sync']['import_folders'].select{ |i| i != '--all--' } if @configs['contacts_sync']['import_folders'].present?
        Integrations::ContactsSync::Base.perform_async(APP_NAME, :sync_contacts_first_time, { "sync_account_id" => @sync_account.id, "import_folders" => import_folders })
      rescue Exception => e
        Rails.logger.error "Problem in pushing job to sidekiq. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, { :custom_params => { :account_id => Account.current.id, :params => params.to_json } })
      end
    end

    def get_selected_field_arrays(fields)
      outlook_fields = []
      fd_fields = []
      fields.each { |field|
        outlook_fields << field["outlook_field"]
        fd_fields << field["fd_field"]
      }
      {"fd_fields" => fd_fields, "outlook_fields" => outlook_fields}
    end

    def fetch_metadata_fields
      outlook_metadata_fields
      fd_metadata_fields
      @element_config['element_validator'] = VALIDATOR
      @element_config['fd_validator'] = FD_VALIDATOR
    end

    def outlook_metadata_fields
      @element_config = Hash.new
      element_metadata = OUTLOOK_METADATA
      hash = map_fields( element_metadata )
      @element_config["contact_fields"] = hash['fields_hash']
      @element_config["contact_fields_types"] = hash['data_type_hash']
    end

    def fd_metadata_fields
      contact_metadata = current_account.contact_form.fields
      contact_hash = fd_fields_hash( contact_metadata )
      @element_config['fd_contact'] = contact_hash['fields_hash']
      @element_config['fd_contact_types'] = contact_hash['data_type_hash']
    end

    def fd_fields_hash(object)
      fields_hash = {}
      data_type_hash = {}
      data_types = CONTACT_TYPES
      object.each do |field|
        fields_hash[field[:name]] = field[:label]
        data_type_hash[field[:label]] = data_types[field[:field_type].to_s]
      end
      {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
    end

    def map_fields(metadata)
      fields_hash = {}
      data_type_hash = {}
      metadata.each do |field|
        label = field['vendorDisplayName']
        fields_hash[field['vendorPath']] = label
        data_type_hash[label] = field['vendorNativeType']
      end
      {'fields_hash' => fields_hash, 'data_type_hash' => data_type_hash }
    end

    def construct_synced_contacts(sync_account)
      @element_config['existing_contacts'] = Array.new
      contact_synced = sync_account.configs['contacts']
      contact_synced['fd_fields'].each_with_index do |fd_field, index|
        @element_config['existing_contacts'].push({'fd_field' => fd_field, 'outlook_field' => contact_synced['outlook_fields'][index]})
      end
    end

    def generate_redis_key
      key_options = { :account_id => current_account.id, :provider => APP_NAME }
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      kv_store
    end

end
