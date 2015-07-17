class ApiCompaniesController < ApiApplicationController
  before_filter :set_required_fields, only: [:create, :update]
  before_filter :set_validatable_custom_fields, only: [:create, :update]
  skip_before_filter :load_objects, only: [:index]

  def index
    load_objects scoper.includes(:flexifield)
  end

  private

    def scoper
      current_account.companies
    end

    def validate_params
      allowed_custom_fields = Helpers::CompaniesValidationHelper.companies_custom_field_keys
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      fields = CompanyConstants::COMPANY_FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      company = ApiCompanyValidation.new(params[cname], @item)
      render_error company.errors, company.error_options unless company.valid?
    end

    def manipulate_params
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def set_validatable_custom_fields
      @item.validatable_custom_fields = { fields: current_account.company_form.custom_company_fields,
                                          error_label: :label }
    end

    def set_required_fields
      @item.required_fields = { fields: current_account.company_form.agent_required_company_fields,
                                error_label: :label }
    end
end
