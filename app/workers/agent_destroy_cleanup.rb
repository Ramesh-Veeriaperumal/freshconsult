class AgentDestroyCleanup < BaseWorker

  sidekiq_options :queue => :agent_destroy_cleanup, :retry => 0, :backtrace => true, :failures => :exhausted

  USER_ASSOCIATED_MODELS = [:report_filters]
  
  attr_accessor :args

  def perform(args)
    begin
      args.symbolize_keys!
      @args    = args
      @account = Account.current
      delete_user_associated
    rescue Exception => e
      puts e.inspect, args.inspect
      NewRelic::Agent.notice_error(e, {:args => args})
    end
  end

  private

    def delete_user_associated
      USER_ASSOCIATED_MODELS.each do |model|
        @account.send(model).where(:user_id => args[:user_id]).destroy_all if args[:user_id].present?
      end
    end
end

