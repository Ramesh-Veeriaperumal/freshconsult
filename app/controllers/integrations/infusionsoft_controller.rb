class Integrations::InfusionsoftController < Integrations::CrmAppsController
   include Integrations::Infusionsoft::InfusionsoftUtil

   before_filter :get_installed_app, :only => [:edit, :fields_update, :fetch_user]
   before_filter :construct_app, :only => [:install]
   before_filter :load_fields, :only => [:install, :edit]

  def install
    get_default_fields_params
    update_crm_fields and return
    render_fields
  end

  def fetch_user
    oauth_token = @installed_app.configs[:inputs]['oauth_token']
    params['rest_url'] = params['rest_url'] + oauth_token
    key = FETCH_INFUSIONSOFT_USERS % {:account_id => current_account.id, :inst_app_id => @installed_app.id }
    http_resp = {}
    response = MemcacheKeys.fetch(key, EXPIRY_TIME){
                hrp = HttpRequestProxy.new
                req_params = {:user_agent => request.headers['HTTP_USER_AGENT']}
                http_resp = hrp.fetch_using_req_params params, req_params
                http_resp[:status] == 200 ? http_resp : nil             
             }
    result = http_resp.blank? ? response : http_resp
    render :xml => result[:text]
  end
    
  def fields_update
    handle_params("contact")
    handle_params("account")
    update_crm_fields and return
    redirect_to integrations_applications_path
  end

  private

   def config_hash
     key_options = { :account_id => current_account.id, :provider => APP_NAMES[:infusionsoft]}
     kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
     kv_store.group = :integration
     app_config = kv_store.get_key
     kv_store.remove_key
     if app_config.blank?
        flash[:error] = t(:'flash.application.install.error')
        redirect_to integrations_applications_path and return
     end
     hash = JSON.parse(app_config)
     hash.delete('app_name')
     hash
   end

   def handle_params(type)
     params["#{type}_data_types"] = params["#{type}_data_types"].split(' ')
     custom_fields = Array.new
     data_types = Array.new
     params["#{type}_custom_fields"].split(' ').each_with_index do | item, index|
      next if params["#{type}s"].exclude? item
      custom_fields.push(item)
      data_types.push(params["#{type}_data_types"][index])
    end
    @installed_app["configs"][:inputs]["#{type}_custom_fields"] = custom_fields.join(',') if custom_fields.present?
    @installed_app["configs"][:inputs]["#{type}_data_types"] = data_types.join(',') if data_types.present?
   end

   def load_fields  
     @fields = Hash.new 
     @fields['contact_fields'] = get_is_object_metadata(CONTACT_FORMID)
     @fields['account_fields'] = get_is_object_metadata(ACCOUNT_FORMID) if @fields['contact_fields']
     if @fields['contact_fields'].blank? || @fields['account_fields'].blank?
       flash[:notice] = t(:'integrations.infusionsoft.customfields_error')
       redirect_to integrations_applications_path and return
     end  
   end
end