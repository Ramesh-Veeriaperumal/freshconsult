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
      allowed_custom_fields = @company_fields.map(&:api_name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      @rename_fields_hash = ParamsHelper.prepend_with_cf_for_custom_fields params[cname][:custom_fields]
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
      @rename_fields_hash.merge!(item.rename_fields_hash) if item.respond_to?(:rename_fields_hash)
      ErrorHelper.rename_error_fields(@rename_fields_hash, item)
    end

    def error_options_mappings
      @rename_fields_hash
    end
end
