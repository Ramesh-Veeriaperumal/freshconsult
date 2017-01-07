TRUSTED_PERIOD = 30

namespace :dkim do

  desc 'Execute DKIM category changer'
  task :run => :environment do
    include Redis::RedisKeys
    include Redis::OthersRedis
    
    execute_category_switcher
  end
end

def execute_category_switcher
  account_id_list = get_others_redis_list(DKIM_CATEGORY_KEY).uniq
  Rails.logger.debug "account_id_list :: #{account_id_list}"
  return account_id_list if account_id_list.count.zero?
  account_id_list.each do |account_id|
    begin
      execute_on_slave(account_id){
        account = Account.find_by_id(account_id).make_current
        next unless account.subscription.state.eql?(Subscription::ACTIVE)
        if eligible_for_category_change?
          DkimCategoryChangerWorker.perform_async
        end
      }
    rescue Exception => e
      puts "Error occured #{e}" 
    end
    Account.reset_current_account
  end
end


def execute_on_slave(account_id)
  Sharding.select_shard_of(account_id) do
    Sharding.run_on_slave do
      yield
    end
  end
end


def eligible_for_category_change?
  trusted_account? and all_domains_activated? and domain_categories_in_trial?
end

def trusted_account?
  Account.current.created_at < TRUSTED_PERIOD.days.ago
end

def all_domains_activated?
  scoper = Account.current.outgoing_email_domain_categories
  scoper.dkim_activated_domains.count == scoper.dkim_configured_domains.count
end

def domain_categories_in_trial?
  return false if Account.current.outgoing_email_domain_categories.count.zero?
  category = OutgoingEmailDomainCategory::SMTP_CATEGORIES[Subscription::TRIAL]
  Account.current.outgoing_email_domain_categories.where(:category => category).count.nonzero?
end