module AccountMetricHelperMethods
  MODELS_TO_IGNORE = [Account, AdminUser, AffiliateDiscount, AffiliateDiscountMapping,
                      CustomFields::Migrations::CustomFieldData, Delayed::Job, DomainMapping,
                      FlexifieldPicklistVal, GlobalBlacklistedIp, Helpdesk::Mysql::DynamicTable,
                      Helpdesk::NoteBody, Helpdesk::TicketBody, Integrations::AppBusinessRule,
                      Integrations::Widget, Moderatorship, PasswordReset, PodShardCondition, ShardMapping, SQSPost,
                      Subscription::Addon, Subscription::Currency, Subscription::PlanAddon,
                      SubscriptionAffiliate, SubscriptionAnnouncement, SubscriptionPlan,
                      Freshfone::Address, GoogleDomain, Helpdesk::UserAccess, Helpdesk::GroupAccess,
                      DeletedCustomers, Wf::Filter, Integrations::GoogleAccount].freeze

  MODEL_META = [
    'facebook_tickets',
    'facebook_notes',
    'orphan_topics',
    'twitter_tickets',
    'twitter_notes'
  ].freeze

  def build_model_data(account)
    data = []
    subclasses = ActiveRecord::Base.subclasses
    subclasses.each do |subclass|
      unless MODELS_TO_IGNORE.include?(subclass)
        count = subclass.where(:account_id => account.id).count
        data << [subclass.to_s, count]
      end
    end
    MODEL_META.each do |model_meta|
      data << [model_meta, safe_send(model_meta, account)]
    end
    data
  end

  # forums
  def orphan_topics(account)
    account.topics.select{ |t| t.posts_count > 1}.count
  end
  
  # facebook
  def facebook_tickets(account)
    account.facebook_posts.where("postable_type = 'Helpdesk::Ticket'").count
  end

  def facebook_notes(account)
    account.facebook_posts.where("postable_type = 'Helpdesk::Note'").count
  end

  # twitter
  def twitter_tickets(account)
    account.tweets.where("tweetable_type = 'Helpdesk::Ticket'").count
  end

  def twitter_notes(account)
    account.tweets.where("tweetable_type = 'Helpdesk::Note'").count
  end

  
end
