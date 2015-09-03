class ApiCompaniesController < ApiApplicationController
  def create
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_errors(company_delegator.errors, company_delegator.error_options)
    elsif @item.save
      decorate_object
      render_201_with_location(item_id: @item.id)
    else
      render_errors(@item.errors)
    end
  end

  def update
    @item.assign_attributes(params[cname])
    @item.custom_field = @item.custom_field
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_errors(company_delegator.errors, company_delegator.error_options)
    elsif @item.update_attributes(params[cname])
      decorate_object
    else
      render_errors(@item.errors)
    end
  end

  private

    def load_objects
      super scoper.includes(:flexifield)
    end

    def decorate_object
      # only methods in BaseDecorator are used in views. Hence a custom decorator class is not defined.
      @item = ApiCompaniesDecorator.new(@item)
    end

    def decorate_objects
      @items.map! { |item| ApiCompaniesDecorator.new(item) }
    end

    def scoper
      current_account.companies
    end

    def validate_params
      @company_fields = current_account.company_form.custom_company_fields
      allowed_custom_fields = @company_fields.collect(&:name)
      custom_fields = allowed_custom_fields.empty? ? [nil] : allowed_custom_fields
      fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
      params[cname].permit(*(fields))
      company = ApiCompanyValidation.new(params[cname], @item)
      render_errors company.errors, company.error_options unless company.valid?
    end

    def sanitize_params
      prepare_array_fields [:domains]
      params[cname][:domains] = params[cname][:domains].join(',') unless params[cname][:domains].nil?
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end
end
