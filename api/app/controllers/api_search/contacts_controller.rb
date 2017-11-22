module ApiSearch
  class ContactsController < SearchController
    decorate_views
    def index
      response = Fql::Runner.instance.construct_es_query('user',params[:query])
      if response.valid?
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(response.terms, page, ApiSearchConstants::CONTACT_ASSOCIATIONS, ['user'])
      else
        render_errors response.errors, response.error_options
      end
    end

    private

      def decorator_options
        super({ name_mapping: Account.current.contact_form.custom_contact_fields.each_with_object({}) { |field, hash| hash[field.name] = CustomFieldDecorator.display_name(field.name) } })
      end
  end
end