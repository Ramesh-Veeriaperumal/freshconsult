class ApiContactsController < ApiApplicationController
  include Helpdesk::TagMethods
  decorate_views

  around_filter :run_on_slave, only: [:index]

  def create
    assign_protected
    contact_delegator = ContactDelegator.new(@item, email_objects: @email_objects, custom_fields: params[cname][:custom_field])
    if !contact_delegator.valid?
      render_custom_errors(contact_delegator, true)
    else
      build_user_emails_attributes if @email_objects.any?
      if @item.create_contact!
        render_201_with_location(item_id: @item.id)
      else
        render_custom_errors
      end
    end
  end

  def update
    assign_protected
    custom_fields = params[cname][:custom_field] # Assigning it here as it would be deleted in the next statement while assigning.
    # Assign attributes required as the contact delegator needs it.
    @item.assign_attributes(validatable_delegator_attributes)
    contact_delegator = ContactDelegator.new(@item, email_objects: @email_objects, custom_fields: custom_fields)
    unless contact_delegator.valid?
      render_custom_errors(contact_delegator, true)
      return
    end
    build_user_emails_attributes if @email_objects.any?
    render_custom_errors unless @item.update_attributes(params[cname])
  end

  def destroy
    @item.update_attribute(:deleted, true)
    head 204
  end

  def make_agent
    return if invalid_params_or_state?
    if @item.make_agent(params[cname])
      @agent = Agent.find_by_user_id(@item.id)
    else
      render_errors(@item.errors)
    end
  end

  def self.wrap_params
    ContactConstants::WRAP_PARAMS
  end

  private

    # Same as http://apidock.com/rails/Hash/extract! without the shortcomings in http://apidock.com/rails/Hash/extract%21#1530-Non-existent-key-semantics-changed-
    # extract the keys from the hash & delete the same in the original hash to avoid repeat assignments
    def validatable_delegator_attributes
      params[cname].select { |key, value| (params[cname].delete(key); true) if ContactConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES.include?(key) }
    end

    def decorator_options
      super({ name_mapping: (@name_mapping || get_name_mapping) })
    end

    def get_name_mapping
      # will be called only for index and show.
      # We want to avoid memcache call to get custom_field keys and hence following below approach.
      custom_field = index? ? @items.first.try(:custom_field) : @item.custom_field
      custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
    end

    def after_load_object
      @item.account = current_account if scoper.attribute_names.include?('account_id')
      action_scopes = ContactConstants::SCOPE_BASED_ON_ACTION[action_name] || {}
      action_scopes.each_pair do |scope_attribute, value|
        item_value = @item.send(scope_attribute)
        if item_value != value
          Rails.logger.debug "Contact id: #{@item.id} with #{scope_attribute} is #{item_value}"
          # Render 405 in case of update/delete as it acts on contact endpoint itself
          # And User will be able to GET the same contact via Show
          # other URLs such as contacts/id/make_agent will result in 404 as it is a separate endpoint
          update? || destroy? ? render_405_error(['GET']) : head(404)
          return false
        end
      end
    end

    def invalid_params_or_state?
      return true if blank_email? # invalid state because agent can't be created without email.
      if params[cname].present?
        invalid_params? 
      else
        agent_limit_reached?
      end
    end

    def blank_email?
      if @item.email.blank?
        render_request_error :inconsistent_state, 409
      end
    end

    # returns true if it fails params validation either in data type validation or in delegator validation.
    def invalid_params?
      params[cname].permit(*(ContactConstants::MAKE_AGENT_FIELDS))
      make_agent = MakeAgentValidation.new(params[cname], @item)
      if make_agent.valid?
        ParamsHelper.assign_and_clean_params({ ticket_scope: :ticket_permission, signature: :signature_html }, params[cname])
        agent_delegator = AgentDelegator.new(params[cname].slice(:role_ids, :group_ids))
        render_errors(agent_delegator.errors, agent_delegator.error_options) if agent_delegator.invalid?
      else
        render_errors(make_agent.errors, make_agent.error_options)
      end
    end

    # returns true if agent limit is reached for the account. No more full time agents can't be created.
    # Will return 403 as make_agent action considers full time agent creation if no params in request.
    def agent_limit_reached?
      agent_limit_reached, agent_limit = ApiUserHelper.agent_limit_reached?
      if agent_limit_reached
        render_request_error :max_agents_reached, 403, max_count: agent_limit 
      end
    end

    def validate_params
      @contact_fields = current_account.contact_form.custom_contact_fields
      @name_mapping = CustomFieldDecorator.name_mapping(@contact_fields)
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values

      field = ContactConstants::CONTACT_FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(field))
      ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
      contact = ContactValidation.new(params[cname], @item, string_request_params?)
      render_custom_errors(contact, true)  unless contact.valid?(action_name.to_sym)
    end

    def sanitize_params
      params_hash = params[cname]
      params_hash[:tag_names] = sanitize_tags(params_hash.delete(:tags)).join(',') if create? || params_hash.key?(:tags)

      # Making the view_all_tickets as the last entry in the params_hash, since company_id
      # has to be initialised first for making a contact as a view_all_tickets
      params_hash[:view_all_tickets] = params_hash.delete(:view_all_tickets) if params_hash.key?(:view_all_tickets)

      if params_hash[:avatar]
        extension = File.extname(params_hash[:avatar].original_filename).downcase
        params_hash[:avatar].content_type = ContactConstants::AVATAR_CONTENT[extension]
        params_hash[:avatar_attributes] = { content: params_hash.delete(:avatar) }
      end

      # email has to be saved in downcase to maintain consistency between user_emails table and users table
      params_hash[:email].downcase! if params_hash[:email]

      @email_objects = {}
      construct_all_emails(params_hash) if params_hash.key?(:other_emails)

      ParamsHelper.assign_checkbox_value(params_hash[:custom_fields], current_account.contact_form.custom_checkbox_fields.map(&:name)) if params_hash[:custom_fields]

      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field, view_all_tickets: :client_manager }, params_hash)
    end

    def construct_all_emails(params_hash)
      all_emails = params_hash.delete(:other_emails)

      # If an existing user has an uppercase email, save it in downcase to maintain constistency with user_emails table
      primary_email = params_hash.key?(:email) ? params_hash.delete(:email) : @item.email.downcase

      if primary_email
        @email_objects[:primary_email] = primary_email
        all_emails << primary_email
      end

      all_emails.map!(&:downcase).uniq!

      @email_objects[:old_email_objects]  = current_account.user_emails.where(email: all_emails)
      @email_objects[:new_emails]  = all_emails - @email_objects[:old_email_objects].collect(&:email)
    end

    def validate_filter_params
      params.permit(*ContactConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @contact_filter = ContactFilterValidation.new(params, nil, string_request_params?)
      render_errors(@contact_filter.errors, @contact_filter.error_options) unless @contact_filter.valid?
    end

    def load_objects
      # preload(:flexifield) will avoid n + 1 query to contact field data.
      super contacts_filter(scoper).preload(:flexifield).order('users.name')
    end

    def contacts_filter(contacts)
      @contact_filter.conditions.each do |key|
        clause = contacts.contact_filter(@contact_filter)[key.to_sym] || {}
        contacts = contacts.where(clause[:conditions]).joins(clause[:joins])
      end
      contacts
    end

    def scoper
      current_account.all_contacts
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(ContactConstants::FIELD_MAPPINGS.merge(@name_mapping), item)
    end

    def error_options_mappings
      @name_mapping.merge(ContactConstants::FIELD_MAPPINGS)
    end

    def assign_protected
      @item.deleted = true if @item.email.present? && @item.email =~ ContactConstants::MAILER_DAEMON_REGEX
    end

    def valid_content_type?
      return true if super
      allowed_content_types = ContactConstants::ALLOWED_CONTENT_TYPE_FOR_ACTION[action_name.to_sym] || [:json]
      allowed_content_types.include?(request.content_mime_type.ref)
    end

    def build_user_emails_attributes
      email_attributes = []
      primary_email = @email_objects[:primary_email]

      # old emails to be retained
      @email_objects[:old_email_objects].each do |user_email|
        email_attributes << { 'email' => user_email.email, 'id' => user_email.id, 'primary_role' => user_email.email == primary_email }
      end

      # new emails to be added
      @email_objects[:new_emails].each do |email|
        email_attributes << { 'email' => email, 'primary_role' => email == primary_email }
      end

      # emails to be destroyed
      if update?
        emails_to_be_destroyed =  (@item.user_emails - @email_objects[:old_email_objects])
        emails_to_be_destroyed.each do |user_email|
          email_attributes << { 'email' => user_email.email, 'id' => user_email.id, '_destroy' => 1 }
        end
      end

      @item.user_emails_attributes = Hash[(0...email_attributes.size).zip email_attributes]
    end

    # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
    wrap_parameters(*wrap_params)
end
