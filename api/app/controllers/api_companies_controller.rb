class ApiCompaniesController < ApiApplicationController
  def create
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_errors(company_delegator.errors, company_delegator.error_options)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      render_errors(@item.errors)
    end
  end

  def update
    @item.assign_attributes(params[cname])
    @item.custom_field = @item.custom_field # assign custom_field so that it will not be queried again in model callbacks
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_errors(company_delegator.errors, company_delegator.error_options)
    elsif !@item.update_attributes(params[cname])
      render_errors(@item.errors)
    end
  end

  private

    def load_objects
      # preload(:flexifield) will avoid n + 1 query to company field data.
      super scoper.preload(:flexifield).order(:name)
    end

    def scoper
      current_account.companies
    end

    def validate_params
      @company_fields = current_account.company_form.custom_company_fields
      allowed_custom_fields = @company_fields.map(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      company = ApiCompanyValidation.new(params[cname], @item)
      render_errors company.errors, company.error_options unless company.valid?
    end

    def sanitize_params
      prepare_array_fields [:domains]
      params[cname][:domains] = params[cname][:domains].join(',') unless params[cname][:domains].nil?
      ParamsHelper.assign_checkbox_value(params[cname][:custom_fields], current_account.company_form.custom_checkbox_fields.map(&:name)) if params[cname][:custom_fields]
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end
end
