module FilterFactory::Tickets
  module SanitizeMethods
    private

      def fetch_filter_conditions
        conditions = []
        conditions += args[:data_hash] if args[:data_hash]
        conditions += default_filter_data(args[:filter_name]) if args[:filter_name]
        conditions
      end

      def default_filter_data(filter)
        Helpdesk::Filters::CustomTicketFilter.new.default_filter(filter.to_s) || []
      end

      def fetch_missing_fields  # Check if necessary after implementing fql and sql
        args[:conditions].map { |condition| condition['condition'] if include_choice?(condition['value'], '-1') }.compact
      end

      def handle_errors(&block)
        yield
      rescue FilterFactory::Errors::UnknownQuerySourceException => e
        Rails.logger.error "Error in FilterFactory :: #{e.inspect} :: #{fetch_context}"
        NewRelic::Agent.notice_error(e, "Invalid source used for querying :: #{fetch_context}")
      rescue FilterFactory::Errors::FQLFormatException => e
        Rails.logger.error "FQL format error in FilterFactory :: #{e.inspect}"
        NewRelic::Agent.notice_error(e, 'Invalid FQL format')
      rescue FilterFactory::Errors::FQLValidationException => e
        Rails.logger.error "FQL mapping validation error in FilterFactory :: #{e.inspect}"
        NewRelic::Agent.notice_error(e, 'Validation failed for FQL mapping')
      end

      def include_choice?(value, choice)
        value.is_a?(Array) ? value.include?(choice) : value.to_s.split(',').include?(choice)
      end
  end
end
