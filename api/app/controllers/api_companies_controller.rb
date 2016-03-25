class ApiCompaniesController < ApiApplicationController
  decorate_views

  around_filter :run_on_slave, :only => [:index]

  def create
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_custom_errors(company_delegator, true)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      render_custom_errors
    end
  end

  def update
    @item.assign_attributes(params[cname])
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_custom_errors(company_delegator, true)
    elsif !@item.update_attributes(params[cname])
      render_custom_errors
    end
  end

  private

    def validate_filter_params
      params.permit(*CompanyConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @company_filter = CompanyFilterValidation.new(params, nil, string_request_params?)
      render_errors(@company_filter.errors, @company_filter.error_options) unless @company_filter.valid?
    end

    def load_objects
      # preload(:flexifield) will avoid n + 1 query to company field data.
      super scoper.preload(:flexifield).order(:name)
      # includes(:flexifield) will avoid n + 1 query to company field data.
      super companies_filter(scoper).includes(:flexifield).order(:name)
    end

    def companies_filter(companies)
      @company_filter.conditions.each do |key|
        clause = companies.company_filter(@company_filter)[key.to_sym] || {}
        companies = companies.where(clause[:conditions]).joins(clause[:joins])
      end
      companies
    end

    def scoper
      current_account.companies
    end

    def validate_params
      @company_fields = current_account.company_form.custom_company_fields
      @name_mapping = CustomFieldDecorator.name_mapping(@company_fields)
      custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
      fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
      company = ApiCompanyValidation.new(params[cname], @item)
      render_custom_errors(company, true) unless company.valid?
    end

    def sanitize_params
      prepare_array_fields [:domains]
      params[cname][:domains] = params[cname][:domains].join(',') unless params[cname][:domains].nil?
      ParamsHelper.assign_checkbox_value(params[cname][:custom_fields], current_account.company_form.custom_checkbox_fields.map(&:name)) if params[cname][:custom_fields]
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields({ base: :domains }.merge(@name_mapping), item)
    end

    def error_options_mappings
      @name_mapping
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
end
