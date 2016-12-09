module ApiSearch
  class CompaniesController < SearchController

    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      sanitize_custom_fields(record, ApiSearchConstants::COMPANY_FIELDS) if custom_fields.any?

      validation_params = record.merge({company_fields: company_fields })

      validation = Search::CompanyValidation.new(validation_params)

      if validation.valid?
        search_terms = tree.accept(visitor)
        ids = ids_from_esv2_response(query_es(search_terms, :companies))
        @items = ids.any? ? paginate_items(scoper.where(id: ids)) : []
        @name_mapping = custom_fields
      else
        render_custom_errors(validation, true)
      end
    end

    private

      def custom_fields
        @custom_fields ||= company_custom_fields.each_with_object({}) { |field, hash| hash[field.name] =  CustomFieldDecorator.display_name(field.name) }
      end

      def visitor
        column_names = company_custom_fields.each_with_object({}) { |field, hash| hash[CustomFieldDecorator.display_name(field.name).to_sym] = field.column_name }
        Search::TermVisitor.new(column_names)
      end

      def scoper
        current_account.companies.preload(:flexifield, :company_domains)
      end

      def company_custom_fields
        company_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type.to_s }
      end

      def company_fields
        Account.current.company_form.company_fields_from_cache
      end
  end
end
