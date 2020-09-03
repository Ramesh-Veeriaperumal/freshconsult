module OmniChannelRouting
  class TaskSync < BaseWorker
    include ::OmniChannelRouting::Util

    sidekiq_options queue: :ocr_task_sync, retry: 5,  failures: :exhausted

    def perform(args)
      args.symbolize_keys!
      account = Account.current
      payload = { attributes: args[:attributes], changes: args[:changes] }
      Rails.logger.debug "***** OCR payload #{payload.inspect}"
      response = request_service(:freshdesk, :put, service_paths[:update_ticket] % { ticket_id: args[:id].to_s }, payload.to_json)
      Rails.logger.info "Task changes sync successful. A=#{account.id} T=#{args[:id]} Response:: #{response}"
    rescue Exception => e
      Rails.logger.error "Error while syncing task changes #{e.message} :: #{e.backtrace[0..10].inspect}"
      NewRelic::Agent.notice_error(e, { account_id: account.id, args: args })
      raise e
    end
  end
end
