class ApiContactsController < ApiApplicationController
  wrap_parameters :api_contact, exclude: [], format: [:json, :multipart_form]

  include Helpdesk::TagMethods
  include APIHelperMethods

  before_filter :validate_filter_params, only: [:index]
  before_filter :check_agent_limit, :can_make_agent, only: [:make_agent]

  def index
    load_objects contacts_filter(scoper)
  end

  def contacts_filter(contacts)
    @contact_filter.conditions.each do |key|
      clause = contacts.api_filter(@contact_filter)[key.to_sym] || {}
      contacts = contacts.where(clause[:conditions])
    end
    contacts
  end

  def create
    @item  = scoper.new()
    user = { user: params[cname] }
    if @item.signup!(user)
      render "#{controller_path}/create", location: send("#{nscname}_url", @item.id), status: 201
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  def update
    if params[cname][:tags]
      @item.tags = []
      update_tags(params[cname][:tags], true, @item)
      params[cname].delete(:tags)
    end
    super
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def restore
    @item.update_attribute(:deleted, false)
    head 204
  end

  def make_agent
    if @item.make_agent
      @agent = Agent.find_by_user_id(@item.id)
    else
      render_error(@item.errors)
    end   
  end

  private

    def scoper
      current_account.all_contacts
    end

    def validate_params
      allowed_custom_fields = current_account.contact_form.contact_fields_from_cache.select { |field| field[:column_name] != 'default' }.collect(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields      
      field = ContactConstants::CONTACT_FIELDS | [ 'custom_fields' => custom_fields ]
      field = field | [ 'avatar_attributes' => ['content'] ] if params[cname][:avatar_attributes]
      params[cname].permit(*(field))
      contact = ContactValidation.new(params[cname], @item)
      render_error contact.errors, contact.error_options unless contact.valid?
    end

    def manipulate_params
      params[cname][:tags] = params[cname][:tags].join(",") if params[cname][:tags]
      params[cname][:client_manager] = params[cname][:client_manager].to_s if params[cname][:client_manager]
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def build_object

    end

    def validate_filter_params
      params.permit(*ContactConstants::INDEX_CONTACT_FIELDS, *ApiConstants::DEFAULT_PARAMS,
                    *ApiConstants::DEFAULT_INDEX_FIELDS)
      @contact_filter = ContactFilterValidation.new(params)
      render_error(@contact_filter.errors, @contact_filter.error_options) unless @contact_filter.valid?
    end

    def load_object
      condition = 'id = ? '
      condition += "and deleted = #{ContactConstants::DELETED_SCOPE[action_name]}" if ContactConstants::DELETED_SCOPE.keys.include?(action_name)
      @item = scoper.where(condition, params[:id]).first
      head :not_found unless @item
    end
    
    def check_agent_limit
      if current_account.reached_agent_limit? 
        # error_message = { :errors => { :message => t('maximum_agents_msg') }}  
        # render :json => error_message, :status => :bad_request
        @errors = [BadRequestError.new('id', 'You have reached the maximum number of agents your subscription allows. You need to delete an existing agent or contact your account administrator to purchase additional agents.')]
        render '/bad_request_error', status: 400
      end
    end
    
    def can_make_agent
      unless @item.has_email?
        @errors = [BadRequestError.new('email', 'Contact with email id can only be converted to agent')]
        render '/bad_request_error', status: 400
      end
    end
end
