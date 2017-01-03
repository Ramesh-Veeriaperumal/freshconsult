class Integrations::CloudElements::CrmController < Integrations::CloudElementsController
  include Integrations::CloudElements::Crm::Constant
  include Integrations::CloudElements::Constant
  include Integrations::CloudElements::Crm::CrmUtil

  before_filter :check_feature, :verify_authenticity
  before_filter :build_installed_app, :check_element_instances, :only => [:instances, :create]
  before_filter :load_installed_app, :only => [:edit, :update, :fetch]
  before_filter :migrate_integrated_resources, :only => [:update], :if => :element_is_salesforce?
  before_filter :update_obj_transformation, :only => [:update]
  before_filter :update_formula_inst, :only => [:update]
  
  def settings
    build_setting_configs "settings"
    render :template => "integrations/applications/crm_settings"
  end

  def create
    el_response = create_element_instance( crm_payload, @metadata ) #what will happen If the user closes the window at this stage??
    redirect_to "#{request.protocol}#{request.host_with_port}#{integrations_cloud_elements_crm_instances_path}?state=#{params[:state]}&method=post&id=#{el_response['id']}&token=#{CGI::escape(el_response['token'])}"
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error inside crm_controller::create Message: #{e}", :account_id => current_account.id}})
    hash = build_setting_configs "create"
    flash[:error] = t(:'flash.application.install.cloud_element_settings_failure')
    render :template => "integrations/applications/crm_settings", :locals => {:configs => hash}
  end

  def instances
    if params[:id].present? and params[:token].present?
      el_response, el_response_id, el_response_token = true, params[:id], params[:token]
    else
      el_response = create_element_instance( crm_payload, @metadata )
      el_response_id, el_response_token = el_response['id'], el_response['token']
    end
    Rails.logger.debug "#{element} Instance Created successfully, Id: #{el_response_id}"
    fd_response = create_element_instance( fd_payload, @metadata )
    Rails.logger.debug "Freshdesk Instance Created successfully, Id: #{fd_response['id']}"
    fetch_metadata_fields(el_response_token)
    crm_formula_resp = create_formula_inst(el_response_id, fd_response['id'], "crm")
    fd_formula_resp = create_formula_inst(el_response_id, fd_response['id'], "freshdesk")
    Rails.logger.debug "Formula Instances Created successfully, CRM Id: #{crm_formula_resp['id']}, FD ID: #{fd_formula_resp['id']}"
    app_configs = get_app_configs(el_response_token, el_response_id, fd_response['id'], crm_formula_resp['id'], fd_formula_resp['id'])
    @installed_app.configs[:inputs].merge!(app_configs)
    @installed_app.save!
    flash[:notice] = t(:'flash.application.install.cloud_element_success')
    render_settings
  rescue => e
    Rails.logger.error "Error inside crm_controller::instances Message: #{e}"
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application: #{e.message}", :account_id => current_account.id}})
    if crm_formula_resp.present? and crm_formula_resp['id'].present?
      formula_template_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[element]
      options = {:object => NOTATIONS[:formula], :app_id => @installed_app.application_id, :metadata => {:formula_template_id => formula_template_id, :id => crm_formula_resp['id']}}
      Integrations::CloudElementsDeleteWorker.perform_async(options)
    end
    if fd_formula_resp.present? and fd_formula_resp['id'].present?
      formula_template_id = Integrations::HELPDESK_TO_CRM_FORMULA_ID[element]
      options = {:object => NOTATIONS[:formula], :app_id => @installed_app.application_id, :metadata => {:formula_template_id => formula_template_id, :id => fd_formula_resp['id']}}
      Integrations::CloudElementsDeleteWorker.perform_async(options)
    end
    if el_response.present? and el_response_id.present?
      options = {:object => NOTATIONS[:element], :app_id => @installed_app.application_id, :metadata => {:id => el_response_id}}
      Integrations::CloudElementsDeleteWorker.perform_async(options)
    end
    if fd_response.present? and fd_response['id'].present?
      options = {:object => NOTATIONS[:element], :app_id => @installed_app.application_id, :metadata => {:id => fd_response['id']}}
      Integrations::CloudElementsDeleteWorker.perform_async(options)
    end
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Queueing done successfully: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path 
  end

  def edit
    fetch_metadata_fields(@installed_app.configs_element_token)
    @element_config['enable_sync'] = @installed_app.configs_enable_sync
    default_mapped_fields
    construct_synced_contacts
    render_settings
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def update
    @installed_app.set_configs get_metadata_fields
    @installed_app.save!
    flash[:notice] = t(:'flash.application.update.success')
    redirect_to integrations_applications_path
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def fetch
    payload = JSON.parse(params[:payload], :symbolize_names => true)
    constant_file = get_crm_constants
    metadata = @metadata
    metadata = @metadata.merge({:element_token => @installed_app.configs_element_token, :object => constant_file['objects'][payload[:type]], :object_id => constant_file['Id']}) unless NO_METADATA_EVENTS.include? params[:event] 
    if payload[:type] == "contact"
      response = service_obj( payload, metadata).receive("#{params[:event]}".to_sym)
      metadata[:account_object] = constant_file['objects']['account']
      response = get_contact_account_name response, metadata
    elsif payload[:type] == "account" && payload[:value][:email].present?
      response = get_contact_account_ids payload[:value][:email], metadata
      accIds = Array.new
      response["records"].each do |res|
       accIds.push(res["accountId"])  if res["accountId"].present?
      end
      query = accIds.collect{|id| "#{constant_file['account_name_format']}='#{id}'"}.join(" OR ")
      payload[:value][:query] = query
      response = get_contact_accounts payload
    else
      response = service_obj( payload, metadata).receive("#{params[:event]}".to_sym)
    end
    web_meta = @cloud_elements_obj.web_meta
    hash = {}
    hash[web_meta.delete(:content_type)] = response
    hash.merge!(web_meta)
    render(hash)
  end

  private

  def crm_payload
    json_payload = "Integrations::CloudElements::Crm::Constant::#{element.upcase}_JSON".constantize
    json_payload % instance_hash
  end

  def fd_payload
    json_payload = FRESHDESK_JSON
    api_key = current_user.single_access_token
    tz = ActiveSupport::TimeZone.new(current_account.time_zone).to_s
    tz =~ /\((.*)\)/
    JSON.generate(json_payload) % {:api_key => api_key, :subdomain => subdomain, :fd_instance_name => "freshdesk_#{element}_#{subdomain}_#{current_account.id}", :time_zone => $1}
  end

  def fetch_metadata_fields(element_token)
    crm_element_metadata_fields(element_token)
    fd_metadata_fields
  end

  def update_obj_transformation
    sync_hash = get_synced_objects
    @contact_metadata = @metadata.merge({:object => 'fdContact', :method => params[:method]})
    @account_metadata = @metadata.merge({:object => 'fdCompany', :method => params[:method]})
    sync_frequency_change = params['sync_frequency'] != @installed_app.configs_sync_frequency
    element_object_transformation sync_hash, @installed_app.configs_element_instance_id, "crm", sync_frequency_change
    element_object_transformation sync_hash, @installed_app.configs_fd_instance_id, "fd", sync_frequency_change
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in updating the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path
  end

  def create_formula_inst( element_instance_id, fd_instance_id, action)
    metadata, payload = if action == "crm" 
      formula_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[element] 
      [ @metadata.merge({:formula_id => formula_id}), formula_instance_payload( "#{element}_#{subdomain}_#{current_account.id}", element_instance_id, fd_instance_id, true )] 
    else
      constant_file = get_crm_constants
      formula_id = Integrations::HELPDESK_TO_CRM_FORMULA_ID[element]
      [ @metadata.merge({:formula_id => formula_id}), formula_instance_payload( "Freshdesk_#{element}_#{subdomain}_#{current_account.id}", fd_instance_id, element_instance_id, true )]
    end
    create_formula_instance(payload, metadata)
  end

  def update_formula_inst
    #checking any change in the enable_sync or the crm_sync_type only then Formula Instances will be changed.
    if params['crm_sync_type'] != @installed_app.configs_crm_sync_type || params[:enable_sync] != @installed_app.configs_crm_sync_type
      #==================================CRM Formula Instance Updation===========================
      formula_id = Integrations::CRM_TO_HELPDESK_FORMULA_ID[element]
      metadata = @metadata.merge({:formula_id => formula_id, :formula_instance_id => @installed_app.configs_crm_to_helpdesk_formula_instance})
      payload = formula_instance_payload( "#{element}_#{subdomain}_#{current_account.id}", @installed_app.configs_element_instance_id, @installed_app.configs_fd_instance_id , check_sync_active("crm"))
      update_formula_instance(payload, metadata)
      #==================================Freshdesk Formula Instance Updation=====================
      fd_formula_id = Integrations::HELPDESK_TO_CRM_FORMULA_ID[element]
      metadata = @metadata.merge({:formula_id => fd_formula_id, :formula_instance_id => @installed_app.configs_helpdesk_to_crm_formula_instance})
      payload = formula_instance_payload( "Freshdesk_#{element}_#{subdomain}_#{current_account.id}", @installed_app.configs_fd_instance_id, @installed_app.configs_element_instance_id, check_sync_active("fd"))
      update_formula_instance(payload, metadata)
    end
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing the application: #{e.message}", :account_id => current_account.id}})
    flash[:error] = t(:'flash.application.update.error')
    redirect_to integrations_applications_path and return 
  end

end