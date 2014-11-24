require File.expand_path('../spam_constants', __FILE__)
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
        :key => SpamConstants::SPAM_WATCHER[self.table_name]["key_space"], 
        :threshold => SpamConstants::SPAM_WATCHER[self.table_name]["threshold"],
        :sec_expire => SpamConstants::SPAM_WATCHER[self.table_name]["sec_expire"],
      }
      generate_spam_watcher_methods
    end

    def generate_spam_watcher_methods
      user_column, key  = self.spam_watcher_options[:user_column],self.spam_watcher_options[:key]
      threshold,sec_expire =  self.spam_watcher_options[:threshold], self.spam_watcher_options[:sec_expire]
      class_eval %Q(
        after_commit_on_create :spam_watcher_counter
        def spam_watcher_counter
          begin
            Timeout::timeout(SpamConstants::SPAM_TIMEOUT) {
              if "#{user_column}".blank?
                user_id = ""
              else
                user_id = self.send("#{user_column}") 
              end
              account_id = self.account_id
              key = "#{key}"
              max_count = "#{threshold}".to_i
              final_key = key + ":" + account_id.to_s + ":" + user_id.to_s
              # this case is added for the sake of skipping imports
              return true if (((key == "sw_helpdesk_tickets") or (key == "sw_helpdesk_notes")) && ((Time.now.to_i - self.created_at.to_i) > 1.day))
              return true if $spam_watcher.get(account_id.to_s + "-" + user_id.to_s)
              count = $spam_watcher.rpush(final_key, Time.now.to_i)
              sec_expire = "#{sec_expire}".to_i 
              $spam_watcher.expire(final_key, sec_expire+1.minute)
              if count >= max_count
                head = $spam_watcher.lpop(final_key).to_i
                time_diff = Time.now.to_i - head
                if time_diff <= sec_expire
                  # ban_expiry = sec_expire - time_diff
                  $spam_watcher.rpush(SpamConstants::SPAM_WATCHER_BAN_KEY,final_key)
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
