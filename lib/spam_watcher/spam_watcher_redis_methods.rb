require 'email_helper'

class SpamWatcherRedisMethods
  CMRR_CUTOFF = 5000.freeze
  SPAM_NOTICED = 'noticed spamming,'.freeze
  SPAM_BLOCKED = 'blocked spamming,'.freeze

  extend EmailHelper
  class << self
    def block_spam_user(user)
      user.blocked = true
      user.blocked_at = Time.zone.now + 10.years

      subject = "User #{user.id} blocked - for Account-id: #{user.account.id}"
      additional_info = "User blocked due to spam activity"
      # notify_account_blocks(user.account, subject, additional_info)
      update_freshops_activity(user.account, "User blocked due to spam activity", "block_user")

      user.save(:validate => false)
    end

    def delete_user(user)
      user.deleted = true
      user.deleted_at = Time.zone.now
      user.save(:validate => false)
    end

    def paid_account?(account)
      (account.subscription.amount > 0 && account.subscription.state == 'active')
    end

    def spam_url(account,user,table)
      shard_mapping = ShardMapping.lookup_with_account_id(account.id)
      type = table.split("_").last
      "https://freshopsadmin.freshdesk.com/#{shard_mapping.pod_info}/#{shard_mapping.shard_name}/spam_watch/#{user.id}/#{type}"
    end

    def spam_alert(account,user,table_name,operation,subject,deleted_flag)
      hit_count = current_hit_count account, user, table_name
      subscription = account.subscription
      subject = subject.blank? ? "New Spam Watcher Abnormal load in #{table_name} : Spam Count #{hit_count}" : "#{subject} Abnormal load #{table_name} : Spam Count #{hit_count}"
      subject << ": Account #{account.id} : State #{subscription.state} : MRR #{subscription.amount}"
      subject << " : Agent #{user.helpdesk_agent}" if user.present?
      FreshdeskErrorsMailer.deliver_spam_watcher(
        {
          subject: subject,
          additional_info: {
            operation: operation,
            full_domain: account.full_domain,
            account_id: account.id,
            user_id: user.id,
            admin_url: spam_url(account, user, table_name),
            signature: 'Spam Watcher',
            deleted_flag: deleted_flag
          }
        }
      )
    end

    def spam_blocked_alert(account)
      SubscriptionNotifier.send_email(:deliver_admin_spam_watcher_blocked, account.admin_email, account)
      FreshdeskErrorsMailer.deliver_spam_blocked_alert(
        {
          :subject          => "Blocked Account with id #{account.id} Due to heavy creation of solution articles",
          :additional_info  => {
            :account_id  => account.id,
            :full_domain  => account.full_domain,
            :signature => "Spam Watcher"
          }
        }
      )

      subject = "Account blocked - Account-id: #{account.id} due to heavy creation of solution articles"
      additional_info = "Due to heavy creation of solution articles"
      notify_account_blocks(account, subject, additional_info)
      update_freshops_activity(account, "Account blocked due to heavy creation of solution articles", "block_account")
    end

    def has_whitelisted_and_keyset?(account_id, user_id)
      WhitelistUser.find_by_account_id_and_user_id(account_id, user_id) || $spam_watcher.exists("spam_tickets_#{account_id}_#{user_id}") 
    end

    def load_account_details(account_id, user_id)
      account = nil, user = nil
      account = Account.find_by_id(account_id)
      user = user_id ? User.find_by_id(user_id) : nil
      return account, user
    end

    def check_spam(account, user, table_name)
      subscription = account.subscription
      if subscription.cmrr > CMRR_CUTOFF
        return if user.agent?

        spam_alert(account, user, table_name, SPAM_NOTICED, nil, 0)
      elsif (subscription.free? || subscription.active?) && user.agent?
        subject = 'Spam Watcher - Detected Suspicious'
        spam_alert(account, user, table_name, SPAM_NOTICED, subject, 0)
      else
        block_spam_user(user) if account.block_spam_user_enabled?
        subject = 'Spam Watcher - Blocked Suspicious'
        spam_alert(account, user, table_name, SPAM_BLOCKED, subject, account.block_spam_user_enabled? ? 1 : 0)
      end
    end

    def solution_articles(account)
      return if $spam_watcher.exists("spam_solutions_#{account.id}")
      return if(paid_account?(account) || ((Time.now - 2.days).to_i - account.created_at.to_i) > 0)
      spam_blocked_alert(account)
      sub = account.subscription
      sub.state = "suspended"
      sub.save
      $spam_watcher.setex("spam_solutions_#{account.id}",6.hours,"true")
      shard_map = ShardMapping.find(account.id)
      shard_map.status = ShardMapping::STATUS_CODE[:not_found]
      shard_map.save
      return 
    end

    def current_hit_count account, user, table_name
      account_id = account.nil? ? "" : account.id.to_s
      user_id =  user.nil? ? "" : user.id.to_i
      final_key = "sw_#{table_name}:#{account_id}:#{user_id}"
      $spam_watcher.perform_redis_op("llen",final_key)
    end

    def spam_threshold account_id, user_id, model
      # get threshold for all three 
      # if not available get for account and model
      # if not go with default for the subscription plan
      account, user = load_account_details(account_id, user_id)
      threshold = spam_threshold_for_account account, user, model
      threshold = spam_threshold_for_account account, nil, model if threshold.nil?
      if threshold.nil?
        threshold = default_spam_threshold_based_on_account_status account, model, user
        set_spam_threshold_for_account account_id, model, threshold
      end
      threshold
    end

    def spam_threshold_for_account account, user, model
      user_id = user.nil? ? "" : user.id.to_s
      account_id = account.nil? ? "" : account.id.to_s
      key = spam_threshold_key account_id, user_id, model
      $spam_watcher.perform_redis_op("get",key)
    end

    def set_spam_threshold_for_account account_id, model, threshold
      key = spam_threshold_key account_id, nil, model
      $spam_watcher.setex(key, 24.hours.to_i, threshold)
    end

    def spam_threshold_key account_id, user_id, model
      SPAM_THRESHOLD%{account_id: account_id, user_id: user_id, model: model}
    end

    def default_spam_threshold_based_on_account_status(account, model, user)
      if(!account.nil? && !account.subscription.nil?)
        state = account.subscription.state
      end
      state = state.nil? ? "" : state
      agent = user.present? && user.class == User && user.try(:helpdesk_agent)
      key = default_spam_threshold_key state, model, agent
      default_threshold = $spam_watcher.perform_redis_op("get",key)
      default_threshold = SpamConstants::AGENT_SPAM_WATCHER[model]['threshold'] if default_threshold.blank? && agent
      default_threshold
    end

    def default_spam_threshold_key(state, model, agent)
      agent ? format(DEFAULT_AGENT_SPAM_THRESHOLD, state: state, model: model) : format(DEFAULT_SPAM_THRESHOLD, state: state, model: model)
    end

    def incoming_email_spam(account)
      return if $spam_watcher.exists("spam_emails_#{account.id}")
      return if(paid_account?(account) || ((Time.now - 2.days).to_i - account.created_at.to_i) > 0)
      incoming_email_spam_block_alert(account)
      sub = account.subscription
      sub.state = "suspended"
      sub.save
      $spam_watcher.setex("spam_emails_#{account.id}",6.hours,"true")
      shard_map = ShardMapping.find(account.id)
      shard_map.status = ShardMapping::STATUS_CODE[:not_found]
      shard_map.save
      return 
    end

    def incoming_email_spam_block_alert(account)
      SubscriptionNotifier.send_email(:deliver_admin_spam_watcher_blocked, account.admin_email, account)
      FreshdeskErrorsMailer.deliver_spam_blocked_alert(
        {
          :subject          => "Blocked Account with id #{account.id} Due to spike in incoming email immediately after signup",
          :additional_info  => {
            :account_id  => account.id,
            :full_domain  => account.full_domain,
            :signature => "Spam Watcher"
          }
        }
      )

      subject = "Account blocked - Account-id: #{account.id} due to spike in incoming email immediately after signup"
      additional_info = "Due to spike in incoming email immediately after signup"
      notify_account_blocks(account, subject, additional_info)
      update_freshops_activity(account, "Account blocked due to spike in incoming email immediately after signup", "block_account")
    end

  end
end
