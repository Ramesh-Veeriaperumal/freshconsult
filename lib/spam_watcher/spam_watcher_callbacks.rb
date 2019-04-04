require File.expand_path('../spam_constants', __FILE__)
require 'spam_watcher/spam_watcher_redis_methods'
require "timeout"

module SpamWatcherCallbacks
  include SpamConstants
  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def spam_watcher_callbacks(options = {})
      class_attribute :spam_watcher_options
      self.spam_watcher_options = {
        :user_column => options[:user_column],
        :import_column => options[:import_column],
        :key => SpamConstants::SPAM_WATCHER[self.table_name]["key_space"], 
        :threshold => SpamConstants::SPAM_WATCHER[self.table_name]["threshold"],
        :sec_expire => SpamConstants::SPAM_WATCHER[self.table_name]["sec_expire"],
      }
      init_spam_watcher_redis_script
      generate_spam_watcher_methods
    end

    def init_spam_watcher_redis_script
      class_attribute :spam_check_redis_script
      self.spam_check_redis_script = %Q(
        local acc_key = KEYS[1]
        local spam_watch_key = KEYS[2]
        local spam_ban_key = KEYS[3]
        local now = tonumber(ARGV[1])
        local expire_time = tonumber(ARGV[2])
        local threshold = tonumber(ARGV[3])
        if redis.call("get", acc_key) then
          return
        end
        local count = redis.call("rpush", spam_watch_key, now)
        redis.call("expire", spam_watch_key, expire_time)
        if count >= threshold then
          local head = redis.call("lpop", spam_watch_key)
          if (now-head) <= expire_time then
            redis.call("rpush", spam_ban_key, spam_watch_key)
          end
        end
      return
      ).freeze

      $spam_watcher.perform_redis_op('script', :load, self.spam_check_redis_script)
      class_attribute :spam_check_redis_script_sha
      self.spam_check_redis_script_sha = Digest::SHA1.hexdigest(self.spam_check_redis_script).freeze
    end

    def generate_spam_watcher_methods
      user_column, key, import_column  = self.spam_watcher_options[:user_column],
                                         self.spam_watcher_options[:key], 
                                         self.spam_watcher_options[:import_column]
      threshold,sec_expire =  self.spam_watcher_options[:threshold], self.spam_watcher_options[:sec_expire]

      class_eval %Q(
        after_commit :spam_watcher_counter, on: :create
        def spam_watcher_counter
          import_column = "#{import_column}"
          return if import_column.present? && self.safe_send(import_column)
          begin
            Timeout::timeout(SpamConstants::SPAM_TIMEOUT) {
              if "#{user_column}".blank?
                user_id = ""
              else
                user_id = self.safe_send("#{user_column}") 
              end
              account_id = self.account_id
              key = "#{key}"
              max_count = "#{threshold}".to_i
              threshold_from_redis = SpamWatcherRedisMethods.spam_threshold account_id, user_id, key
              max_count = threshold_from_redis.to_i unless threshold_from_redis.nil?
              final_key = key + ":" + account_id.to_s + ":" + user_id.to_s
              # this case is added for the sake of skipping imports
              return true if (((key == "sw_helpdesk_tickets") or (key == "sw_helpdesk_notes")) && ((Time.now.to_i - self.created_at.to_i) > 1.day))
              begin
                $spam_watcher.evalsha(self.spam_check_redis_script_sha, [account_id.to_s + "-" + user_id.to_s, final_key, SpamConstants::SPAM_WATCHER_BAN_KEY], [Time.now.to_i, "#{sec_expire}".to_i+1.minute, max_count])
              rescue Redis::BaseError => e
                Rails.logger.error e.backtrace
                NewRelic::Agent.notice_error(e, description: "Error occured in running of spam_watcher redis script")
                if e.message =~ /NOSCRIPT No matching script/
                  self.class.init_spam_watcher_redis_script
                  $spam_watcher.evalsha(self.spam_check_redis_script_sha, [account_id.to_s + "-" + user_id.to_s, final_key, SpamConstants::SPAM_WATCHER_BAN_KEY], [Time.now.to_i, "#{sec_expire}".to_i+1.minute, max_count])
                end
              end
          }
          rescue Exception => e
            Rails.logger.error e.backtrace
            NewRelic::Agent.notice_error(e,{:description => "error occured in updating spam_watcher_counter"})
          end
        end
      )
    end
  end
end
