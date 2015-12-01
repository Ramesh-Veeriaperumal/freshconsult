class ApiCompaniesController < ApiApplicationController
  def create
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_custom_errors(company_delegator, true)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      render_errors(@item.errors)
    end
  end

  def update
    @item.assign_attributes(params[cname])
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_custom_errors(company_delegator, true)
    elsif !@item.update_attributes(params[cname])
      render_errors(@item.errors)
    end
  end

  private

    def load_objects
      # includes(:flexifield) will avoid n + 1 query to company field data.
      super scoper.includes(:flexifield).order(:name)
    end

    def scoper
      current_account.companies
    end

    def validate_params
      @company_fields = current_account.company_form.custom_company_fields
      allowed_custom_fields = @company_fields.collect{ |x| [x.name.to_sym, x.api_name.to_sym] }.to_h
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields.values
      fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      @custom_fields_api_name_mapping = allowed_custom_fields
      ParamsHelper.prepend_with_cf_for_custom_fields(params[cname][:custom_fields], @custom_fields_api_name_mapping)
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
      ErrorHelper.rename_error_fields(@custom_fields_api_name_mapping, item)
    end

    def error_options_mappings
      @custom_fields_api_name_mapping
    end
end
