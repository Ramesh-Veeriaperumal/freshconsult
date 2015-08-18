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
    @item.custom_field = @item.custom_field
    company_delegator = CompanyDelegator.new(@item)
    if !company_delegator.valid?
      render_errors(company_delegator.errors, company_delegator.error_options)
    elsif !@item.update_attributes(params[cname])
      render_errors(@item.errors)
    end
  end

  private

    def load_objects
      super scoper.includes(:flexifield)
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
      convert_domains_to_array if update?
      company = ApiCompanyValidation.new(params[cname], @item)
      render_errors company.errors, company.error_options unless company.valid?
    end

    def sanitize_params
      if params[cname][:domains].nil?
        params[cname][:domains] = (params[cname].key?(:domains) ? '' : @item.domains) if update?
      end
      params[cname][:domains] = params[cname][:domains].join(',') unless params[cname][:domains].nil?
      ParamsHelper.assign_and_clean_params({ custom_fields: :custom_field }, params[cname])
    end

    def convert_domains_to_array
      api_domains = csv_to_array(@item.domains)
      @item.domains = api_domains if api_domains
    end

    def csv_to_array(string_csv)
      string_csv.split(',') unless string_csv.nil?
    end
end
