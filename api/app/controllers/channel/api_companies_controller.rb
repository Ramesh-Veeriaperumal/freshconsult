module Channel
  class ApiCompaniesController < ::ApiCompaniesController
    include ChannelAuthentication
    
    before_filter :channel_client_authentication

    def create
      delegator_params = construct_delegator_params
      company_delegator = CompanyDelegator.new(@item, delegator_params)
      if !company_delegator.valid?(:channel_company_create)
        render_custom_errors(company_delegator, true)
      elsif @item.save
        render_201_with_location(item_id: @item.id)
      else
        render_custom_errors
      end
    end
    
    private

      def validate_params
        @company_fields = current_account.company_form.custom_company_fields

        @name_mapping = CustomFieldDecorator.name_mapping(@company_fields)
        custom_fields = @name_mapping.empty? ? [nil] : @name_mapping.values
        fields = CompanyConstants::FIELDS | ['custom_fields' => custom_fields]
        params[cname].permit(*fields)
        ParamsHelper.modify_custom_fields(params[cname][:custom_fields], @name_mapping.invert)
        company = ApiCompanyValidation.new(params[cname], @item)
        render_custom_errors(company, true) unless company.valid?(:channel_company_create)
      end
  end
end
