module ApiSearch
  class CompaniesController < SearchController
    decorate_views
    def index
      fq_builder = Freshquery::Builder.new.query do |builder|
        builder[:account_id]    = current_account.id
        builder[:context]       = :search_company_api
        builder[:current_page]  = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        builder[:types]         = ['company']
        builder[:es_models]     = ApiSearchConstants::COMPANY_ASSOCIATIONS
        builder[:query]         = params[:query]
      end
      response = fq_builder.response
      if response.valid?
        @items = response.items
      else
        render_errors response.errors, response.error_options
      end
    end

    private

      def decorator_options
        super({ name_mapping: Account.current.company_form.custom_company_fields.each_with_object({}) { |field, hash| hash[field.name] = CustomFieldDecorator.display_name(field.name) } })
      end
  end
end
