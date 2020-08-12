# frozen_string_literal: true

module CentralPublish
  class ResyncWorker < BaseWorker
    include CentralLib::CentralResyncHelper

    sidekiq_options queue: :central_publish_resync, retry: 1, failures: :exhausted

    # Required Arguments
    # => model_name: Name of the model, (Eg: 'Helpdesk::Ticket', 'Helpdesk::TicketField', 'Agent')
    # => source: The Source from which the request is received, (Eg: 'search', 'reports')
    # => meta_info: Info given by the source, (Eg: { id: 121 })
    # Optional Agruments for Config sync (Required for Data sync)
    # => conditions: Where condition, (Eg: ['display_ids in (1, 2, 3, 4, 5) and deleted = false and spam = false'])
    def perform(args)
      @args = args.symbolize_keys!

      configure_redis_and_execute(@args[:source]) do
        publish_entity_to_central
      end
    end

    private

      def publish_entity_to_central
        sync_entity(@args)
      rescue StandardError => e
        Rails.logger.error "Publishing Entity FAILED => #{e.inspect}"
        NewRelic::Agent.notice_error(e, description: "Error publishing entity for Account: #{Account.current.id}, Service: #{@args[:source]}")
      end
  end
end
