class ApiCompaniesController < ApiApplicationController
  before_filter :set_required_fields, only: [:create, :update]

  def create
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_error(company_delegator.errors, company_delegator.error_options)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      render_error(@item.errors)
    end
  end

  def update
    @item.assign_attributes(params[cname])
    @item.custom_field = @item.custom_field
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_error(company_delegator.errors, company_delegator.error_options)
    elsif !@item.update_attributes(params[cname])
      render_error(@item.errors)
    end
  end

  private

    def load_objects
      super current_account.companies.includes(:flexifield)
    end

    def scoper
      current_account.companies
    end

    def custom_validation_fields
      @company_fields.map { |field| [field.name, field] }.to_h
    end

    def validate_params
      @company_fields = current_account.company_form.custom_company_fields
      allowed_custom_fields = @company_fields.collect(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      fields = CompanyConstants::COMPANY_FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      company = ApiCompanyValidation.new(params[cname], @item, custom_validation_fields)
      render_error company.errors, company.error_options unless company.valid?
    end

    def manipulate_params
      params[cname][:domains] = params[cname][:domains].join(',') unless params[cname][:domains].nil?
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def set_validatable_custom_fields
      @item.validatable_custom_fields = { fields: @company_fields,
                                          error_label: :label }
    end

    def set_required_fields
      @item.required_fields = { fields: current_account.company_form.agent_required_company_fields,
                                error_label: :label }
    end
end
