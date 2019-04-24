class ApiProfilesController < ApiApplicationController

  include HelperConcern
  include Freshid::ControllerMethods

  ROOT_KEY = :agent

  decorate_views(decorate_object: [:show, :update, :reset_api_key])

  def constants_class
    :ProfileConstants.to_s.freeze
  end

  def show
    super
    add_api_meta(response)
  end

  def update
    if @item.update_attributes(params[cname])
      add_api_meta(response)
    else
      render_custom_errors
    end
  end
  
  def reset_api_key
    @item.user.reset_single_access_token
    @item.user.save!
    render :update
  rescue => e
    render_custom_errors @item
  end

  protected

    def allowed_to_access?
      params[:id].to_s == 'me'
    end

    def scoper
      current_account.all_agents
    end

    def load_object
      params[:id] = api_current_user.id
      @item = scoper.find_by_user_id(params[:id])
      log_and_render_404 unless @item
    end

    def validate_params
      params[cname].permit(*ProfileConstants::UPDATE_FIELDS)
      agent = ApiProfileValidation.new(params[cname], @item, string_request_params?)
      render_custom_errors(agent, true) unless agent.valid?
    end

    def sanitize_params
      params_hash = params[cname]
      user_attributes = ProfileConstants::USER_FIELDS & params_hash.keys
      params_hash[:user_attributes] = params_hash.extract!(*user_attributes)
      params_hash[:user_attributes][:id] = @item.try(:user_id)
      ParamsHelper.assign_and_clean_params({ signature: :signature_html }, params_hash)
    end

    def add_api_meta response
      response.api_meta = { csrf_token: form_authenticity_token }
      response.api_meta[:freshid_profile_url] = freshid_profile_url if current_account.freshid_integration_enabled?
    end
end
