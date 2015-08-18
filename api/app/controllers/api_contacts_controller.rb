class ApiContactsController < ApiApplicationController
  include Helpdesk::TagMethods

  before_filter :check_demo_site, only: [:destroy, :update, :create]
  before_filter :validate_filter_params, only: [:index]
  before_filter :check_agent_limit, :can_make_agent, only: [:make_agent]
  before_filter :check_parent, only: :restore

  def index
    load_objects contacts_filter(scoper).includes(:flexifield, :company)
  end

  def contacts_filter(contacts)
    @contact_filter.conditions.each do |key|
      clause = contacts.api_filter(@contact_filter)[key.to_sym] || {}
      contacts = contacts.where(clause[:conditions])
    end
    contacts
  end

  def create
    api_add_tags(@tags, @item, 'User') if @tags
    assign_protected
    contact_delegator = ContactDelegator.new(@item)
    if !contact_delegator.valid?
      render_error(contact_delegator.errors, contact_delegator.error_options)
    elsif @item.api_signup!
      render "#{controller_path}/create", location: send("#{nscname}_url", @item.id), status: 201
    else
      set_custom_errors
      render_error(@item.errors)
    end
  end

  def update
    assign_protected

    @item.assign_attributes(params[cname])
    contact_delegator = ContactDelegator.new(@item)
    if !contact_delegator.valid?
      set_custom_errors(contact_delegator)
      render_error(contact_delegator.errors, contact_delegator.error_options)
    else
      api_update_tags(@tags, @item, 'User') if @tags
      super
    end
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

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields({ company: :company_id, base: :email, 'primary_email.email'.to_sym => :email }, item)
    end

    def validate_params
      @contact_fields = current_account.contact_form.custom_contact_fields
      allowed_custom_fields = @contact_fields.collect(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      field = get_fields("ContactConstants::#{action_name.upcase}_CONTACT_FIELDS") | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      contact = ContactValidation.new(params[cname], @item)
      render_error contact.errors, contact.error_options unless contact.valid?(action_name.to_sym)
    end

    def manipulate_params
      @tags = params[cname][:tags]
      params[cname].delete(:tags) if @tags
      # Making the client_manager as the last entry in the params[cname], since company_id has to be initialised first for
      # making a contact as a client_manager
      params[cname][:client_manager] = params[cname].delete(:client_manager).to_s if params[cname][:client_manager]
      params[cname][:avatar_attributes] = { content: params[cname][:avatar] } if params[cname][:avatar]
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
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

    def assign_protected
      @item.deleted = true if @item.email.present? && @item.email =~ /MAILER-DAEMON@(.+)/i
    end

    def check_agent_limit
      if !current_account.subscription.agent_limit.nil? && current_account.agents_from_cache.find_all { |a| a.occasional == false && a.user.deleted == false }.count >= current_account.subscription.agent_limit
        errors = [[:id, ['reached the maximum number of agents']]]
        render_error errors
      end
    end

    def can_make_agent
      unless @item.has_email?
        errors = [[:email, ['Contact with email id can only be converted to agent']]]
        render_error errors
      end
    end

    def check_demo_site
      if AppConfig['demo_site'][Rails.env] == current_account.full_domain
        errors = [[:error, ["Demo site doesn't have this access!"]]]
        render_error errors
      end
    end

    def check_parent
      head 404 if @item.deleted && !@item.parent.nil?
    end
end
