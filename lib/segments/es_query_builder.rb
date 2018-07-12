module Segments
  class EsQueryBuilder
    include EsQueryConstants
    # commented lines are to support date fields

    def initialize(filter_data, contact_segment)
      @filter_data = filter_data
      @result = []
      @current_account = Account.current
      @contact_segment = contact_segment
      # @date_keys = []
      @number_keys = NUMBER_KEYS.dup
    end

    def generate
      map_data_type_with_keys
      filter_conditions.each do |data|
        if data['condition'].eql?(CREATED_AT) # || @date_keys.include?(data['condition'])
          @result << build_date_operation(data)
        elsif OPERTORS.include?(data['operator'])
          @result << send("#{data['operator']}_operator", map_fields(data))
        end
      end
      build_and_operator(@result).to_json
    end

    private

      def bool_operator(data)
        "#{data['condition']}:#{!data['value'].to_i.zero?}"
      end

      def in_operator(data)
        if data['value'].is_a?(Array)
          res = data['value'].map do |val|
            build_pair(data['condition'], val)
          end
          build_or_operator(res)
        else
          build_pair(data['condition'], data['value'])
        end
      end

      alias equal_operator in_operator
      alias is_in_operator in_operator

      def greater_than_operator(data)
        build_pair(data['condition'], (handle_date(data['value']) + 1), GREATER_THAN)
      end

      alias is_greater_than_operator greater_than_operator

      def less_than_operator(data)
        build_pair(data['condition'], (handle_date(data['value']) - 1), LESSER_THAN)
      end

      alias is_less_than_operator less_than_operator

      def between_operator(data)
        generate_range_query(data, data['value']['from'].to_i, data['value']['to'].to_i)
      end

      alias is_between_operator between_operator

      def handle_date(value)
        value.is_a?(Date) ? value : value.to_i
      end

      def build_pair(key, value, operator = '')
        if @number_keys.include?(key)
          "#{key}:#{operator}#{handle_number(value)}"
        else
          "#{key}:#{operator}#{handle_nil_values(value)}"
        end
      end

      def build_or_operator(result)
        "(#{result.join(' OR ')})"
      end

      def build_and_operator(result)
        "(#{result.join(' AND ')})"
      end

      def handle_nil_values(value_string)
        value_string.to_s.eql?('-1') ? 'null' : "'#{value_string}'"
      end

      def handle_number(data)
        data.to_i
      end

      def map_fields(data)
        data['condition'] = ES_FIELD_MAPPINGS[data['condition']] if ES_FIELD_MAPPINGS[data['condition']].present?
        data
      end

      def generate_range_query(data, start_value, end_value)
        data['value'] = start_value - 1
        r1 = is_greater_than_operator(data)
        data['value'] = end_value + 1
        r2 = is_less_than_operator(data)
        build_and_operator([r1, r2])
      end

      def build_date_operation(data)
        use_time_zone do
          if data['value'].eql?('today')
            data['value'] = Time.zone.today.to_s(:db)
            equal_operator(data)
          elsif data['value'].eql?('yesterday')
            data['value'] = Date.yesterday.to_s(:db)
            equal_operator(data)
          elsif data['value'].eql?('last_week')
            generate_range_query(data, Time.zone.today - ONE_WEEK, Time.zone.today)
          elsif data['value'].eql?('last_month')
            generate_range_query(data, Time.zone.today - ONE_MONTH, Time.zone.today)
          elsif data['value'].is_a?(Hash)
            handle_hash_date(data)
          end
        end
      end

      def handle_hash_date(data)
        if data['value']['after'].present?
          data['value'] = Date.parse(data['value']['after'])
          is_greater_than_operator(data)
        elsif data['value']['before'].present?
          data['value'] = Date.parse(data['value']['before'])
          is_less_than_operator(data)
        else
          generate_range_query(data, Date.parse(data['value']['from']), Date.parse(data['value']['to']))
        end
      end

      def use_time_zone
        Time.use_zone(TimeZone.set_time_zone) do
          yield
        end
      end

      def filter_conditions
        @filter_conditions ||= (@filter_data.is_a?(Hash) ? @filter_data.values : @filter_data)
      end

      def current_field_set
        @contact_segment ? @current_account.contact_form.contact_fields_from_cache : @current_account.company_form.company_fields_from_cache
      end

      def map_data_type_with_keys
        current_field_set.each do |c_field|
          next unless c_field.column_name.include?(INTEGER)
          @number_keys.push(alter_cf_name(c_field.name))
          # elsif c_field.column_name.include?(DATE_TYPE)
          # @date_keys.push(alter_cf_name(c_field.name))
        end
      end

      def alter_cf_name(name)
        name.sub(/^cf_/, '')
      end
  end
end
