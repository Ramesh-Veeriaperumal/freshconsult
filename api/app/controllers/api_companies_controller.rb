class ApiCompaniesController < ApiApplicationController
  decorate_views

  before_filter :check_if_company_exists, only: [:create, :update]

  def create
    delegator_params = construct_delegator_params
    company_delegator = CompanyDelegator.new(@item, delegator_params)
    given_avatar_id = delegator_params[:avatar_id]
    @item.avatar = company_delegator.draft_attachments.first if given_avatar_id.present?
    assign_uniqueness_validated
    if !company_delegator.valid?
      render_custom_errors(company_delegator, true)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      render_custom_errors
    end
  end

  def update
    delegator_params = construct_delegator_params
    @item.assign_attributes(validatable_delegator_attributes)
    assign_uniqueness_validated
    company_delegator = CompanyDelegator.new(@item, delegator_params)
    if !company_delegator.valid?
      render_custom_errors(company_delegator, true)
    elsif !@item.update_attributes(params[cname])
      render_custom_errors
    end
  end

  private

    def load_objects(filter = nil)
      # preload(:flexifield, :company_domains) will avoid n + 1 query to company field data & company domains
      super (filter || scoper).preload(preload_options).order(:name)
    end

    def check_if_company_exists
      company = Account.current.companies.where(name: cname_params[:name]).first
      if company && company.id.to_s != params[:id]
        @item.errors[:name] << :"has already been taken"
        @additional_info = { company_id: company.id }
        render_custom_errors
      end
    end

    def assign_uniqueness_validated
      @item.uniqueness_validated = true
    end

    def validatable_delegator_attributes
      params[cname].select do |key, value|
        if CompanyConstants::VALIDATABLE_DELEGATOR_ATTRIBUTES.include?(key)
          params[cname].delete(key)
          true
        end
      end
    end

    def preload_options
      [:flexifield, :company_domains, :avatar]
    end

    def scoper
      current_account.companies
    end

    def construct_delegator_params
      { 
        avatar_id: params[cname][:avatar_id],
        custom_fields: params[cname][:custom_field],
        default_fields: params[cname].except(:custom_field),
        enforce_mandatory: params[:enforce_mandatory]
      }
    end

    def validate_params
      @company_fields = current_account.company_form.custom_company_fields
      @name_mapping = CustomFieldDecorator.name_mapping(@company_fields)
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
      fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*fields)
      ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
      company = ApiCompanyValidation.new(params[cname], @item, params[:enforce_mandatory])
      render_custom_errors(company, true) unless company.valid?
    end

    def sanitize_params
      prepare_array_fields [:domains]
      params[cname][:domains] = params[cname][:domains].join(',') unless params[cname][:domains].nil?
      ParamsHelper.assign_checkbox_value(params[cname][:custom_fields], current_account.company_form.custom_checkbox_fields.map(&:name)) if params[cname][:custom_fields]
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def render_custom_errors(item = @item, merge_item_error_options = false)
      errors, options = format_custom_errors(item, merge_item_error_options)
      if errors.messages[:domains].present? && errors.messages.fetch(:domains) == ['has already been taken']
        item.company_domains.each do |cd|
          @existing_company ||= current_account.company_domains.find_by_domain(cd.domain) if cd.new_record?
        end
        errors.add(:domains, @existing_company.domain + ' is already taken by the company with company id:' + @existing_company.company_id.to_s)
        options[:code] = :duplicate_value
      end
      render_errors(errors, options || {})
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(field_mappings, item)
    end

    def error_options_mappings
      field_mappings
    end

    def decorator_options_hash
      { name_mapping: (@name_mapping || get_name_mapping) }
    end

    def decorator_options
      super decorator_options_hash
    end

    def get_name_mapping
      # will be called only for index and show.
      # We want to avoid memcache call to get custom_field keys and hence following below approach.
      custom_field = index? ? @items.first.try(:custom_field) : @item.custom_field
      custom_field.each_with_object({}) { |(name, value), hash| hash[name] = CustomFieldDecorator.display_name(name) } if custom_field
    end

    def field_mappings
      (custom_field_error_mappings || {}).merge(CompanyConstants::FIELD_MAPPINGS)
    end

end
