module Freshquery
  module Parser
    class TermVisitor < Freshquery::Parser::NodeVisitor
      def initialize(mapping)
        @date_fields = mapping.date_fields
        @date_time_fields = mapping.date_time_fields
        @es_keys = mapping.es_keys
        @boolean_fields = mapping.boolean_fields
        @custom_fields = mapping.custom_fields
      end

      def visit_operator(node)
        bool_filter(reduce_level(node.data, node.left, node.right))
      end

      def reduce_level(data, left, right)
        if [data, left.type, right.type] == ['OR', :operand, :operand] && left.key == right.key && [left.value, right.value].exclude?(nil) && @date_fields.exclude?(left.key) && @date_time_fields.exclude?(left.key) && @custom_fields.keys.exclude?(left.key)
          { Freshquery::Constants::ES_OPERATORS[data] => [terms_filter(construct_key(left), [left.value, right.value])] }
        else
          { Freshquery::Constants::ES_OPERATORS[data] => [left.accept(self), right.accept(self)] }
        end
      end

      def visit_operand(node)
        # If we filter for 'false' value for boolean we need to include records with 'nil' too
        key = construct_key(node)
        if @boolean_fields.include?(key) && node.value == 'false'
          bool_filter(must: [
                        bool_filter(should: [
                                      term_filter(key, false),
                                      not_exists_filter(key)
                                    ])
                      ])
        elsif node.action == '<' || node.action == '>'
          operator = Freshquery::Constants::ES_OPERATORS[node.action]
          if @date_fields.include?(key)
            value = (node.action == '<') ? end_of_day(node.value) : beginning_of_day(node.value)
            bool_filter(
              range_filter(key => { operator  => value })
            )
          elsif @date_time_fields.include?(key)
            bool_filter(
              range_filter(key => { operator  => node.value })
            )
          else
            bool_filter(
              range_filter(key => { operator  => node.value })
            )
          end
        elsif node.value.nil?
          not_exists_filter(key)
        elsif @date_fields.include?(key)
          bool_filter(
            range_filter(key => on_a_date(node.value))
          )
        elsif @custom_fields.keys.include?(key) 
          bool_filter({should: term_array(@custom_fields[key], node.value) + [term_filter(Freshquery::Constants::CUSTOM_FIELDS_NAME.fetch(key,key), node.value)]})
        else
          terms_filter(key, [node.value])
        end
      end

      def construct_key(node)
        @es_keys.fetch(node.key, node.key)
      end

      def term_filter(field_name, value)
        { term: { field_name => value } }
      end

      def terms_filter(field_name, array)
        { terms: { field_name => array } }
      end

      def not_exists_filter(field_name)
        bool_filter(must_not: [ { exists: { field: field_name } } ])
      end

      def bool_filter(cond_block)
        { bool: cond_block }
      end

      def term_array(fields, value)
        fields.map do |field|
          term_filter(field, value)
        end
      end

      def range_filter(cond_block)
        { filter: { range: cond_block } }
      end

      def on_a_date(value)
        { gte: beginning_of_day(value), lte: end_of_day(value) }
      end

      def beginning_of_day(value)
        Time.zone.parse(value).beginning_of_day.utc.iso8601
      end

      def end_of_day(value)
        Time.zone.parse(value).end_of_day.utc.iso8601
      end
    end
  end
end
