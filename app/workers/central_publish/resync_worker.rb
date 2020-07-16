require Rails.root.join('lib', 'central_lib', 'central_resync.rb')

module CentralPublish
  class ResyncWorker < BaseWorker
    include CentralLib::CentralReSync

    sidekiq_options queue: :central_publish_resync, retry: 0, failures: :exhausted

    attr_accessor :relation_with_account, :meta_info, :conditions

    def perform(args)
      args.symbolize_keys!
      @relation_with_account = args[:relation_with_account].to_sym
      @meta_info = args[:meta_info]
      @conditions = args[:conditions]
      @source = args[:source]

      publish_entity_to_central
    end

    def publish_entity_to_central
      return unless Account.current.respond_to?(@relation_with_account)

      Account.current.safe_send(@relation_with_account).where(@conditions).sync_entity(@meta_info)
    rescue Exception => e
      Rails.logger.info "Publishing Entity FAILED => #{e.inspect}"
      NewRelic::Agent.notice_error(e, description: "Error publishing entity for Account: #{Account.current.id}, Service: #{@source}")
    end
  end
end
