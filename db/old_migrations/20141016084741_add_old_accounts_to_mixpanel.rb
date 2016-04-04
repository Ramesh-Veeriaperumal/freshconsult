class AddOldAccountsToMixpanel < ActiveRecord::Migration
  shard :all
  def self.up
    Subscription.find_in_batches(:batch_size => 300, :conditions => [ "state != 'suspended'"]) do |subscriptions|
      subscriptions.each do |sub|
        sub.account.make_current
        update_events(sub.account) if Account.find_by_id(sub.account.id)
      end
    end
  end

  def self.update_events(account)
    user_data = {
      :model => 'import',
      :domain => account.full_domain,
      :plan => account.subscription_plan.name,
      :email => account.admin_email, 
      :state => account.subscription.state,
      :account_data => {
        :email_config => { :count => account.email_configs.count },
        :agent => { :count => account.agents.count },
        :social_twitter_handle => { :count => account.twitter_handles.count },
        :social_facebook_page => { :count => account.facebook_pages.count },
        :survey_links_feature => { :enabled => account.features?(:survey_links) },
        :gamification_enable_feature => { :enabled => account.features?(:gamification_enable) },
        :va_rule => { :count => account.va_rules.count },
        :product => { :count => account.products.count }
      }
    }
    MixpanelWorker.perform_async(user_data)
  end
  
  def self.down
  end
end
