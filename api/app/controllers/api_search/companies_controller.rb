module ApiSearch
  class CompaniesController < SearchController
    decorate_views
    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      record = sanitize_custom_fields(record, ApiSearchConstants::COMPANY_FIELDS)

      validation_params = record.merge(company_fields: company_fields)

      validation = Search::CompanyValidation.new(validation_params, company_custom_fields)

      if validation.valid?
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : ApiSearchConstants::DEFAULT_PAGE
        @items = query_results(search_terms, page, ApiSearchConstants::COMPANY_ASSOCIATIONS, ['company'])
      else
        render_custom_errors(validation, true)
      end
    end

    private

      def custom_fields
        @custom_fields ||= Account.current.company_form.custom_company_fields.each_with_object({}) { |field, hash| hash[field.name] = CustomFieldDecorator.display_name(field.name) if field.column_name =~ ApiSearchConstants::CUSTOMER_FIELDS_REGEX }
      end

      def visitor
        column_names = Account.current.company_form.custom_company_fields.each_with_object({}) { |field, hash| hash[CustomFieldDecorator.display_name(field.name)] = field.column_name if field.column_name =~ ApiSearchConstants::CUSTOMER_FIELDS_REGEX }.except(*ApiSearchConstants::COMPANY_FIELDS)
        es_keys = ApiSearchConstants::COMPANY_KEYS
        # date_fields = company_fields.map(&:column_name).select { |x| x if x =~ /^cf_date/ } + ApiSearchConstants::CUSTOMER_DATE_FIELDS.map{|x| es_keys.fetch(x,x) }
        date_fields = ApiSearchConstants::CUSTOMER_DATE_FIELDS
        Search::TermVisitor.new(column_names, es_keys, date_fields, ApiSearchConstants::COMPANY_NOT_ANALYZED)
      end

      def allowed_custom_fields
        # If any custom fields have the name same as that of default fields it will be ignored
        company_custom_fields.each_with_object({}) { |company_field, hash| hash[company_field.name] = CustomFieldDecorator.display_name(company_field.name) unless ApiSearchConstants::COMPANY_FIELDS.include?(CustomFieldDecorator.display_name(company_field.name)) }
      end

      def company_custom_fields
        company_fields.select { |x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include?(x.field_type.to_s) }
      end

      def company_fields
        Account.current.company_form.company_fields_from_cache
      end

      def decorator_options
        super({ name_mapping: custom_fields })
      end
  end
end
