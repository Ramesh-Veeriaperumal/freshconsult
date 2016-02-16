class Integrations::SugarcrmController < Integrations::CrmAppsController
  include Integrations::Sugarcrm::ApiUtil

  before_filter :get_installed_app, :only => [:check_session_id, :renew_session_id, :get_session_id, :edit, :fields_update]
  before_filter :check_installed_app, :only => [:settings, :settings_update]
  before_filter :construct_app, :only => [:settings_update]
  before_filter :get_session_id, :only => [ :edit, :settings_update]
  before_filter :load_fields, :only => [:edit, :settings_update]
  
  def settings_update
    if @api_response
      get_default_fields_params
      update_crm_fields
      render_fields
    else
      render_settings
    end
  end

  def edit
    if @api_response
      render_fields
    else
      redirect_to integrations_applications_path
    end
  end

  def renew_session_id
    session_id_response = fetch_session_id
    data_json = if(!session_id_response[:response_status])
      {"status" => false}
    else
      update_session_id(session_id_response[:data])
      {"status" => true }
    end
    render :json => data_json
  end

  def check_session_id
    data_json = { "status" => false }
    if(@installed_app["configs"][:inputs]["session_id"])
      data_json = { "status" => true }
    end
    render :json => data_json
  end

private
  def config_hash
    hash = { "domain" => params["configs"]["domain"],
             "username" => params["configs"]["username"],
             "encryptiontype" => "md5",
             "password" => params["configs"]["password"]
           }
  end

  def get_session_id
    unless @installed_app["configs"][:inputs]["session_id"]
  	  session_id_response = fetch_session_id
  	  if (!session_id_response[:response_status])
  	  		flash.now[:error] = session_id_response[:error_name]
  	      render_settings
  	    else
  	      update_session_id(session_id_response[:data])
  	   end 
    end     
  end

  def update_session_id session_id
    @installed_app["configs"][:inputs]["session_id"] = session_id
    @installed_app.save unless @installed_app.new_record?
  end

  def load_fields
    @api_response = true
    @fields = {}
    CRM_MODULE_TYPES.each do |key|
      response = get_custom_fields_api(key)
      if(response[:response_status])
        @fields["#{key}_fields"] = {}
        response[:data].each do |value, label|
     		  @fields["#{key}_fields"][label["label"]] = value if SUPPORTED_DATA_TYPE.include? label["type"] 
        end
      else
      	@api_response = false
        flash[:error] = t(:'integrations.sugarcrm.form.error')
        break
  	 	end
  	end
    @api_response
  end
end