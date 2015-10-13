class ApiContactsController < ApiApplicationController
  include Helpdesk::TagMethods

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
    assign_protected
    @item.assign_attributes(params[cname].except('tag_names'))
    contact_delegator = ContactDelegator.new(@item)
    unless contact_delegator.valid?
      render_custom_errors(contact_delegator, true)
      return
    end
    render_custom_errors unless @item.update_attributes(params[cname])
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
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

  def self.wrap_params
    ContactConstants::WRAP_PARAMS
  end

  private

    def load_object
      @item = scoper.find_by_id(params[:id])
      head :not_found unless @item
    end

    def after_load_object
      @item.account = current_account if scoper.attribute_names.include?('account_id')
      scope = ContactConstants::DELETED_SCOPE[action_name]
      if scope != nil && @item.deleted != scope
        head 404
        return false
      end

      # make_agent route doesn't accept any parameters
      if action_name == 'make_agent' && params[cname].present?
        render_request_error :no_content_required, 400
      end
    end

    def validate_params
      @contact_fields = current_account.contact_form.custom_contact_fields
      allowed_custom_fields = @contact_fields.map(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields

      field = ContactConstants::CONTACT_FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))

      contact = ContactValidation.new(params[cname], @item, multipart_or_get_request?)
      render_custom_errors(contact, true)  unless contact.valid?(action_name.to_sym)
    end

    def sanitize_params
      prepare_array_fields [:tags]
      params_hash = params[cname]
      params_hash[:tag_names] = params_hash.delete(:tags).join(',') if params_hash.key?(:tags)

      # Making the client_manager as the last entry in the params_hash, since company_id
      # has to be initialised first for making a contact as a client_manager
      params_hash[:client_manager] = params_hash.delete(:client_manager) if params_hash.key?(:client_manager)

      params_hash[:avatar_attributes] = { content: params_hash[:avatar] } if params_hash[:avatar]

      ParamsHelper.assign_checkbox_value(params_hash[:custom_fields], @contact_fields) if params_hash[:custom_fields]

      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params_hash)
    end

    def validate_filter_params
      params.permit(*ContactConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @contact_filter = ContactFilterValidation.new(params, nil, multipart_or_get_request?)
      render_errors(@contact_filter.errors, @contact_filter.error_options) unless @contact_filter.valid?
    end

    def load_objects
      super contacts_filter(scoper).includes(:flexifield, :company)
    end

    def contacts_filter(contacts)
      @contact_filter.conditions.each do |key|
        clause = contacts.contact_filter(@contact_filter)[key.to_sym] || {}
        contacts = contacts.where(clause[:conditions])
      end
      contacts
    end

    def scoper
      current_account.all_contacts
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields({ company_name: :company_id, tag_names: :tags, company: :company_id, base: :email, 'primary_email.email'.to_sym => :email }, item)
    end

    def error_options_mappings
      {company_name: :company_id, tag_names: :tags}
    end

    def assign_protected
      @item.deleted = true if @item.email.present? && @item.email =~ ContactConstants::MAILER_DAEMON_REGEX
    end

    def reached_agent_limit?
      current_account.agents_from_cache.find_all { |a| a.occasional == false && a.user.deleted == false }.count >= current_account.subscription.agent_limit
    end

    # If false given, nil is getting saved in db as there is nil assignment if blank. Hence assign 0
    def assign_checkbox_value
      check_box_names = @contact_fields.select { |x| x.field_type == :custom_checkbox }.map(&:name)
      params[cname][:custom_fields].each_pair do |key, value|
        next unless check_box_names.include?(key.to_s)
        params[cname][:custom_fields][key] = 0 if value.is_a?(FalseClass) || value == 'false'
      end
    end

    def valid_content_type?
      return true if super
      allowed_content_types = ContactConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
