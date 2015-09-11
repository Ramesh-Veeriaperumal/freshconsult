class ApiContactsController < ApiApplicationController
  include Helpdesk::TagMethods

  before_filter :validate_empty_params, only: [:restore, :make_agent]

  def index
    load_objects contacts_filter(scoper).includes(:flexifield, :company)
  end

  def contacts_filter(contacts)
    @contact_filter.conditions.each do |key|
      clause = contacts.contact_filter(@contact_filter)[key.to_sym] || {}
      contacts = contacts.where(clause[:conditions])
    end
    contacts
  end

  def create
    assign_protected
    contact_delegator = ContactDelegator.new(@item)
    if !contact_delegator.valid?
      render_custom_errors(contact_delegator, true)
    elsif @item.create_contact!
      render "#{controller_path}/create", location: send("#{nscname}_url", @item.id), status: 201
    else
      render_custom_errors
    end
  end

  def update
    params[cname][:deleted] = true if @item.email.present? && @item.email =~ ContactConstants::MAILER_DAEMON_REGEX
    @item.assign_attributes(params[cname].except('tag_names'))
    contact_delegator = ContactDelegator.new(@item)
    if !contact_delegator.valid?
      render_custom_errors(contact_delegator, true)
    elsif @item.update_attributes(params[cname])
      render "#{controller_path}/update", location: send("#{nscname}_url", @item.id), status: 200
    else
      render_custom_errors
    end
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def restore
    # Don't restore the contact if it has a parent
    if @item.deleted && @item.parent_id != 0
      head 404
    else
      @item.update_attribute(:deleted, false)
      head 204
    end
  end

  def make_agent
    if @item.email.blank?
      render_request_error :inconsistent_state, 409
    elsif !current_account.subscription.agent_limit.nil? && reached_agent_limit?
      render_request_error :max_agents_reached, 403
    else
      if @item.make_agent
        @agent = Agent.find_by_user_id(@item.id)
      else
        render_errors(@item.errors)
      end
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
      contact_fields = current_account.contact_form.custom_contact_fields
      allowed_custom_fields = contact_fields.collect(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields

      field = ContactConstants::CONTACT_FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))

      contact = ContactValidation.new(params[cname], @item)
      render_errors contact.errors, contact.error_options unless contact.valid?(action_name.to_sym)
    end

    def validate_empty_params
      params[cname].permit(*ContactConstants::EMPTY_FIELDS)
    end

    def sanitize_params
      prepare_array_fields [:tags]
      params[cname][:tag_names] = params[cname].delete(:tags).collect(&:strip).join(',') if params[cname].key?(:tags)

      # Making the client_manager as the last entry in the params[cname], since company_id has to be initialised first for
      # making a contact as a client_manager
      params[cname][:client_manager] = params[cname].delete(:client_manager).to_s if params[cname][:client_manager]

      params[cname][:avatar_attributes] = { content: params[cname][:avatar] } if params[cname][:avatar]

      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def validate_filter_params
      params.permit(*ContactConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @contact_filter = ContactFilterValidation.new(params)
      render_errors(@contact_filter.errors, @contact_filter.error_options) unless @contact_filter.valid?
    end

    def load_object
      @item = scoper.find_by_id(params[:id])
      head :not_found unless @item
    end

    def after_load_object
      @item.account = current_account if scoper.attribute_names.include?('account_id')
      scope = ContactConstants::DELETED_SCOPE[action_name]
      unless scope.nil?
        if @item.deleted != scope
          head 404
          return false
        end
      end
    end

    def assign_protected
      @item.deleted = true if @item.email.present? && @item.email =~ ContactConstants::MAILER_DAEMON_REGEX
    end

    def reached_agent_limit?
      current_account.agents_from_cache.find_all { |a| a.occasional == false && a.user.deleted == false }.count >= current_account.subscription.agent_limit
    end
end
