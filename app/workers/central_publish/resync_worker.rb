module CentralPublish
  class ResyncWorker < BaseWorker
    include CentralLib::CentralReSync

    sidekiq_options queue: :central_publish_resync, retry: 0, failures: :exhausted

    def perform(args)
      args.symbolize_keys!

      Account.current.safe_send(args[:relation_with_account]).sync_entity(args[:meta_info])
    end
  end
end
