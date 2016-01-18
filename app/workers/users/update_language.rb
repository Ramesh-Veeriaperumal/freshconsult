class Users::UpdateLanguage < BaseWorker

  sidekiq_options :queue => :update_user_language, 
  :retry => 0, 
  :backtrace => true, 
  :failures => :exhausted

  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      account = Account.current
      begin
        records_updated = User.update_all("language = '#{account.language}'", ["account_id = ? and language != ?", account.id, account.language], {:limit => BATCH_LIMIT} )
      end while records_updated == BATCH_LIMIT
    rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
        raise e
    end
  end
end