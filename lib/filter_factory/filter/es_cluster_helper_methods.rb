module FilterFactory::Filter
  module EsClusterHelperMethods
    include FilterFactory::Filter::Mappings
    include Admin::AdvancedTicketing::FieldServiceManagement::Util
    SINGLE_QUOTE = '#&$!SinQuo'.freeze
    DOUBLE_QUOTE = '#&$!DouQuo'.freeze
    BACK_SLASH = '#&$!BacSla'.freeze

    private

      def fetch_fql_condition(field)
        field_name = fetch_field_name(field).to_s
        values = fetch_values(field['value'])
        safe_send("build_#{field['operator']}_query", field_name, values, field['ff_name'])
      end

      def build_is_in_query(field_name, values, field_type = 'default')
        enclose = !(id_fields.include? field_name)
        queries = values.map do |value|
          value.to_s == '-1' ? "#{field_name}:null" : build_string_query(field_name, value, enclose)
        end
        '(' + queries.join(' OR ') + ')'
      end

      def build_is_greater_than_query(field_name, values, _field_type = 'default')
        from = values['from']
        to = values['to']
        if from && to
          "(#{field_name}:>'#{from}' AND #{field_name}:<'#{to}')"
        elsif from
          "#{field_name}:>'#{from}'"
        else
          "#{field_name}:<'#{to}'"
        end
      end

      def build_is_query(field_name, value, _field_type = 'default')
        value.to_s == '-1' ? "#{field_name}:null" : "#{field_name}:#{value}"
      end

      def build_string_query(field_name, value, enclose)
        enclose ? "#{field_name}:'#{encode_value(value)}'" : "#{field_name}:#{value}"
      end

      def fetch_field_name(field)
        if field['ff_name'] && field['ff_name'] != 'default'
          field_name = TicketDecorator.display_name(field['ff_name'])
          TicketFilterConstants::FSM_DATE_TIME_FIELDS.include?(field_name) ? fsm_field_display_name(field_name) : field_name
        else
          column_mappings[field['condition']].presence || field['condition']
        end
      end

      def fetch_values(values)
        values.is_a?(Array) || values.is_a?(Hash) ? values : values.to_s.split(',')
      end

      def text_fields
        "FilterFactory::Filter::Mappings::#{scoper[:documents].upcase}_TEXT_FIELDS".constantize
      end

      def id_fields
        "FilterFactory::Filter::Mappings::#{scoper[:documents].upcase}_ID_FIELDS".constantize
      end

      def column_mappings
        "FilterFactory::Filter::Mappings::#{scoper[:documents].upcase}_COLUMN_MAPPING".constantize
      end

      def fetch_joins
        "FilterFactory::Filter::Mappings::#{scoper[:documents].upcase}_ORDER_MAPPINGS".constantize[order_by.to_sym]
      end

      # Modularize
      def encode_value(value)
        # Hack to handle special chars in query
        return value unless value.is_a? String

        value.gsub(/['"\\]/, '\'' => SINGLE_QUOTE, '"' => DOUBLE_QUOTE, '\\' => BACK_SLASH)
      end

      def decode_values(values)
        # Hack to handle special characters ' " \ in query
        return values unless values.is_a? String

        values.gsub(SINGLE_QUOTE, '\'').gsub(DOUBLE_QUOTE, '\"').gsub(BACK_SLASH, '\\\\\\\\')
      end

      def fetch_ar_records(object_ids)
        scoper[:ar_class].constantize
                         .joins(fetch_joins)
                         .where(account_id: Account.current.id, id: object_ids)
                         .order(fetch_order)
                         .scoped
      end

      def fetch_order
        order = order_by.to_sym
        order_mappings = "FilterFactory::Filter::Mappings::#{scoper[:documents].upcase}_ORDER_BY_MAPPINGS".constantize
        if order_mappings.key?(order)
          safe_send(order_mappings[order], order_by, order_type)
        else
          "#{order_by} #{order_type.upcase}"
        end
      end

      def fetch_fql_runner_response(query)
        runner_response = Freshquery::Runner.instance.construct_es_query(scoper[:documents].to_s, JSON.dump(query))
        raise FilterFactory::Errors::FQLFormatException if runner_response.errors
        raise FilterFactory::Errors::FQLValidationException unless runner_response.valid?
        runner_response
      end

      def construct_search_payload(fql_response)
        doc_types = [scoper[:documents]]
        template = scoper[:context]
        params = {
          search_terms: decode_values(JSON.dump(fql_response.terms)),
          offset: (page.to_i - 1) * per_page.to_i,
          account_id: Account.current.id,
          size: [per_page.to_i + 1, 100].min,
          sort_by: order_by,
          sort_direction: order_type
        }
        SearchService::Utils.construct_payload(doc_types, template, params)
      end

      def fetch_and_conditions
        fql_conditions = []
        conditions.each do |field|
          fql_conditions << fetch_fql_condition(field)
        end
        fql_conditions
      end

      def process_or_conditions  # revisit or logic
        fql_conditions = []
        or_conditions.each do |or_block|
          block_conditions = []
          or_block.each do |field|
            block_conditions << fetch_fql_condition(field)
          end
          fql_conditions << '(' + block_conditions.join(' OR ') + ')'
        end
        fql_conditions
      end
  end
end
