module ApiSearch
  class CompaniesController < SearchController

    def index
      tree = parser.expression_tree
      record = record_from_expression_tree(tree)

      sanitize_custom_fields(record, ApiSearchConstants::COMPANY_FIELDS) if custom_fields.any?

      validation_params = record.merge({company_fields: company_fields })

      validation = Search::CompanyValidation.new(validation_params)

      if validation.valid?
        @name_mapping = custom_fields
        search_terms = tree.accept(visitor)
        page = params[:page] ? params[:page].to_i : 1
        response = query_es(search_terms, :companies)
        @items = query_results(response, page, ApiSearchConstants::COMPANY_ASSOCIATIONS)
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

      def company_custom_fields
        company_fields.select{|x| ApiSearchConstants::ALLOWED_CUSTOM_FIELD_TYPES.include? x.field_type.to_s }
      end

      def company_fields
        Account.current.company_form.company_fields_from_cache
      end
  end
end
