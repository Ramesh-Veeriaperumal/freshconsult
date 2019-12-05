class Admin::TicketFieldWorker < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Admin::TicketFieldHelper

  sidekiq_options :queue => :ticket_field_job, :retry => 0, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    Account.find(account_id).make_current
    tf = args[:ticket_field]
    action = args[:action]
    begin
      tf.field_options[:update_in_progress] = true
      tf.save!
      tf.field_options[:update_in_progress] = false
    rescue => e
      set_others_redis_key(ticket_field_error_key(tf), e.inspect)
      Rails.logger.info "Ticket field update FAILED => #{e.inspect}"
      NewRelic::Agent.notice_error(exception, args: { account_id: Account.id, ticket_field_id: tf.id})
      action == :create ? tf.destroy : tf.reload
    end
  end

  def ticket_field_error_key(tf)
    format(TICKET_FIELD_UPDATE_ERROR, account_id: Account.current.id, ticket_field_id: tf.id)
  end

end