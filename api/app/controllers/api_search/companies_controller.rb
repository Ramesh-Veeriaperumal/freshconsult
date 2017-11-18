module ApiSearch
  class CompaniesController < SearchController
    decorate_views
    def index
      response = Fql::Runner.instance.construct_es_query('company',params[:query])
      if response.valid?
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(response.terms, page, ApiSearchConstants::COMPANY_ASSOCIATIONS, ['company'])
      else
        render_errors response.errors, response.error_options
      end
    end

    private

      def decorator_options
        super({ name_mapping: Account.current.company_form.custom_company_fields.each_with_object({}) { |field, hash| hash[field.name] = CustomFieldDecorator.display_name(field.name) if field.column_name =~ ApiSearchConstants::CUSTOMER_FIELDS_REGEX } })
      end
  end
end