class AccountCleanup::DeleteAccount < BaseWorker
  sidekiq_options queue: :delete_account, retry: 0, failures: :exhausted, backtrace: 50

  include FreshdeskCore::Model
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::DisplayIdRedis
  include SandboxConstants
  include Utils::Freno

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    return if account.active?
    Rails.logger.debug "Params => args[:continue_account_destroy_from]: #{args[:continue_account_destroy_from]}"
    @continue_account_destroy_from = args[:continue_account_destroy_from] || 0
    Rails.logger.debug "@continue_account_destroy_from: #{@continue_account_destroy_from}"
    account.delete_account_cancellation_requested_time_key if account.launched?(:downgrade_policy)
    ::Admin::Sandbox::DeleteWorker.new.perform(event: SANDBOX_DELETE_EVENTS[:deactivate]) if account.production_with_sandbox?
    deleted_customer = DeletedCustomers.find_by_account_id(account.id)

    update_status(deleted_customer, STATUS[:in_progress])

    begin
      clear_account_redis_keys

    rescue Exception  => e
      Rails.logger.info "Redis key deletion error on account cancel - #{e}"
      NewRelic::Agent.notice_error(e)        
    end

    begin
      perform_destroy(account)
      update_status(deleted_customer, STATUS[:deleted])
    rescue ReplicationLagError => e
      rerun_after(e.lag, account.id) if e.lag > 0
    rescue StandardError => error
      Rails.logger.info "Account deletion Error sidekiq - account_id #{account.id}, #{error.inspect}, #{error.backtrace}"
      NewRelic::Agent.notice_error(error)             
      update_status(deleted_customer, STATUS[:failed])
      raise error
    end
  end
  private 


  def update_status(deleted_customer, status)
    deleted_customer.update_attributes(:status => status) if deleted_customer
  end

  def clear_account_redis_keys
    account = Account.current
      #account alone keys
      ACCOUNT_RELATED_KEYS.each do |redis_key|
        key = redis_key % {:account_id => account.id}
        remove_others_redis_key(key)
      end

      #ticket display id is in separate redis store
      DISPLAY_ID_KEYS.each do |redis_key|
        key = redis_key % {:account_id => account.id}
        remove_display_id_redis_key(key)
      end

      #account group keys
      rr_group_ids = account.groups.round_robin_groups.pluck(:id)
      user_ids = account.technicians.pluck(:id)

      rr_group_ids.each do |group_id|
        ACCOUNT_GROUP_KEYS.each do |redis_key|
         key = redis_key % {:account_id => account.id, :group_id => group_id }
         remove_others_redis_key(key)
       end

        #account group user key
        user_ids.each do |user_id|
          ACCOUNT_GROUP_USER_KEYS.each do |redis_key|
            key = redis_key % {:account_id => account.id, :group_id => group_id, :user_id => user_id }
            remove_others_redis_key(key)
          end
        end
      end
      

      #account user keys
      user_ids.each do |user_id|
        ACCOUNT_USER_KEYS.each do |redis_key|
          key = redis_key % {:account_id => account.id, :user_id => user_id }
          remove_others_redis_key(key)
        end
      end

      #account agent id keys - this is using agent.id instead of user.id. 
      ACCOUNT_AGENT_ID_KEYS.each do |redis_key|
        agent_ids = account.agents.pluck(:id)
        agent_ids.each do |agent_id|
         key = redis_key % {:account_id => account.id, :agent_id => agent_id }
         remove_others_redis_key(key)
       end
     end

      #host keys
      ACCOUNT_HOST_KEYS.each do |redis_key|
        host_key = redis_key % {:host => account.host }
        domain_key = redis_key % {:host => account.full_domain }
        remove_others_redis_key(host_key)
        remove_others_redis_key(domain_key)
      end

      #account article id
      ACCOUNT_ARTICLE_KEYS.each do |redis_key|
        account.solution_articles.find_each do |article|
         key = redis_key % {:account_id => account.id, :article_id => article.id }
         remove_others_redis_key(key)
       end
      end

      ACCOUNT_ARTICLE_VERSION_KEYS.each do |redis_key|
        account.solution_article_versions.find_each do |version|
          key = redis_key % { account_id: account.id, article_id: version.article_id, version_id: version.id }
          remove_others_redis_key(key)
        end
      end

      #account article meta
      ACCOUNT_ARTICLE_META_KEYS.each do |redis_key|
        account.solution_article_meta.find_each do |article_meta|
         key = redis_key % {:account_id => account.id, :article_meta_id => article_meta.id }
         remove_others_redis_key(key)
       end
     end

      #account topic
      ACCOUNT_TOPIC_KEYS.each do |redis_key|
        account.topics.find_each do |topic|
         key = redis_key % {:account_id => account.id, :topic_id => topic.id }
         remove_others_redis_key(key)
       end
     end

   end

   def rerun_after(lag, account_id)
     shard_name = ActiveRecord::Base.current_shard_selection.shard.to_s
     Rails.logger.debug("Warning: Freno: AccountCleanup::DeleteAccount: @continue_account_destroy_from: #{@continue_account_destroy_from}, replication lag: #{lag} secs :: shard :: #{shard_name} :: account :: #{account_id}")
     AccountCleanup::DeleteAccount.perform_in(lag.seconds.from_now, {:account_id => account_id,
       :continue_account_destroy_from => @continue_account_destroy_from})
   end

 end
