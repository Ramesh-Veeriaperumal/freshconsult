class Tickets::SelectAll::BatcherWorker < BaseWorker

  include Sidekiq::Worker
  include SelectAllRedisMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  sidekiq_options :queue => 'select_all_batcher', :retry => 0, :dead => true, :failures => :exhausted
  
  BATCH_LIMIT = 500
  TICKETS_LIMIT = 10000
  MAX_TIME_INTERVAL = 2.hours
  MIN_TIME_INTERVAL = 30.minutes

  def perform(params, account_id, user_id, start_id = nil)
    Sharding.select_shard_of(account_id) do
      @account = Account.find(account_id).make_current
      @tickets_processed = 0
      @user = @account.all_users.find_by_id(user_id)
      @user.make_current 
      params.symbolize_keys!
      initialize_batch(params, user_id)
      batch_query = construct_batch_query(params, start_id)
      ticket_batches = execute_batch_query(batch_query)
      append_disable_params(params)
      spawn_next_batch_if_needed(params, ticket_batches)
      spawn_batches(params, ticket_batches)
    end
  rescue => e
    Rails.logger.debug "Sidekiq Select All Batcher Error - #{e}:\nParams: #{params.inspect}\nAccount ID: #{account_id}\n User ID: #{user_id}"
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description => "Sidekiq Select All Batcher Error",
        :params      => params,
        :account_id  => account_id,
        :user_id     => user_id
    }})
    raise e
  ensure
    Account.reset_current_account
    User.reset_current_user
  end

  private

    def initialize_batch(params, user_id)
      @sidekiq_batch = Sidekiq::Batch.new
      set_bulk_action_redis_key(params, @sidekiq_batch.bid)
    end

    def construct_batch_query(params, start_id)
      filter_options = @account.ticket_filters.new(
        Helpdesk::Filters::CustomTicketFilter::MODEL_NAME
      ).deserialize_from_params(params)
      sql_conditions = filter_options.sql_conditions
      joins = filter_options.get_joins(sql_conditions)
      add_created_filter(sql_conditions, params)
      {
        :select     => "helpdesk_tickets.id",
        :conditions => sql_conditions,
        :joins      => joins,
        :batch_size => BATCH_LIMIT,
        :start      => start_id
      }
    end

    def execute_batch_query(batch_query)
      tkt_batch = []
      execute_on_db do 
        @account.tickets.find_in_batches(batch_query) do |tickets|
          ticket_ids = tickets.map(&:id)
          @tickets_processed += ticket_ids.count
          tkt_batch << ticket_ids
          break if tickets_limit_reached?
        end
      end
      # Creating a Dummy Batch if there are no tickets to process by this batch
      # This ensures that the callback get called and also provides a better handle
      # on approximate finishing time of the batches due to FIFO assurance of Sidekiq
      tkt_batch << [] if @tickets_processed == 0
      tkt_batch
    end

    def job_complete_callback(status, options)
      redis_val = get_others_redis_hash(options['batch_redis_key'])
      remove_others_redis_key(options['batch_redis_key'])
      Admin::BulkActionsMailer.bulk_actions_email(redis_val) unless (Rails.env.development? or Rails.env.test?)
    end

    def batch_complete_callback(status, options)
      next_batch_schedule_time = MAX_TIME_INTERVAL - (Time.now.utc - options['current_time'].to_time).to_i

      next_batch_schedule_time = MIN_TIME_INTERVAL if next_batch_schedule_time < MIN_TIME_INTERVAL
      Tickets::SelectAll::BatcherWorker.perform_in(
        next_batch_schedule_time, 
        options['params'],
        options['account_id'],
        options['user_id'],
        options['start_id']
      )
    end

    def spawn_next_batch_if_needed(params, ticket_batches)
      if tickets_limit_reached?
        @sidekiq_batch.on(:complete, 
          "Tickets::SelectAll::BatcherWorker#batch_complete_callback", { 
            'account_id' => @account.id,
            'user_id' => @user.id,
            'params' => params,
            'start_id' => ticket_batches[-1].sort.last + 1,
            'current_time' => Time.now.utc
        })
      else
        @sidekiq_batch.on(:complete, 
          "Tickets::SelectAll::BatcherWorker#job_complete_callback", 
          'batch_redis_key' => bulk_action_redis_key
        )
      end
    end

    def spawn_batches(params, ticket_batches)
      @sidekiq_batch.jobs do
        ticket_batches.each do |tickets|
          Tickets::SelectAll::TicketsWorker.perform_async(tickets, @user.id, params)
        end 
      end
    end

    def add_created_filter(sql_conditions, params)
      sql_conditions[0].concat(%(and helpdesk_tickets.created_at < ?))
      sql_conditions << params[:enqueued_time]
      sql_conditions
    end

    def tickets_limit_reached?
      @tickets_processed >= TICKETS_LIMIT
    end
    
    def append_disable_params(params)
      params[:enable_observer_rule] ||= false
      params[:enable_activities] ||= false
    end
end
