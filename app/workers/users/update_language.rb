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

      account.all_users.where("language != ?", account.language).select(:id).find_in_batches(batch_size: BATCH_LIMIT) do |users|
        user_ids = users.map(&:id)
        account.all_users.where(id: user_ids).update_all(language: account.language)
      end

    rescue Exception => e
        puts e.inspect, args.inspect
        NewRelic::Agent.notice_error(e, {:args => args})
        raise e
    end
  end
end