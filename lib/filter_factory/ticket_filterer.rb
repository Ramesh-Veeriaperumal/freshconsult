module FilterFactory
  class TicketFilterer
    PERMITTED_ARGS = [:filter_name, :data_hash, :conditions, :missing_fields, :include, :order_by,
                      :order_type, :page, :per_page, :query_hash, :updated_since, :ids].freeze

    FINAL_ARGS_PARAMS = [:conditions, :or_conditions, :missing_fields, :include, :order_by, :order_type, :page, :per_page].freeze

    class << self
      attr_accessor :args

      include FilterFactory::Tickets::PermissibleMethods
      include FilterFactory::Tickets::FieldTransformMethods
      include FilterFactory::Tickets::SanitizeMethods

      def filter(args, with_permissible = true)
        @args = args.deep_dup
        handle_errors do
          process_args(with_permissible)
          filterer = FiltersFactory.filterer(fetch_context, @args)
          filterer.execute
        end
      end

      private

        def fetch_context
          Account.current.new_es_api_enabled? ? tickets_es_context : tickets_sql_context
        end

        def process_args(with_permissible)
          args.slice!(*PERMITTED_ARGS)
          args.merge!(permissible_conditions) if with_permissible
          args[:conditions] = fetch_filter_conditions
          handle_custom_field_values
          args.slice!(*FINAL_ARGS_PARAMS)
        end

        def tickets_es_context
          {
            source: :es_cluster,
            scoper: {
              documents: :ticketanalytics,
              context: :searchTicketApi,
              ar_class: 'Helpdesk::Ticket'
            }
          }
        end

        def tickets_sql_context
          {
            source: :sql,
            scoper: 'Helpdesk::Ticket'
          }
        end
    end
  end
end
