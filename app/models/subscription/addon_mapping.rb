class Subscription::AddonMapping < ActiveRecord::Base 
  self.primary_key = :id
  not_sharded

  DROP_DATA_ADDONS  = ["Round Robin"].freeze
  ADD_DATA_ADDONS   = ["Round Robin"].freeze

  belongs_to :subscription, :class_name => "Subscription"
  belongs_to :subscription_addon, :class_name => "Subscription::Addon"

  validates_uniqueness_of :subscription_addon_id, :scope => :subscription_id

  before_create :set_account_id
  after_commit  :add_feature_data,  on: :create
  after_commit  :drop_feature_data, on: :destroy

  def set_account_id
    self.account_id = subscription.account_id
  end

  def add_feature_data
    if DROP_DATA_ADDONS.include?(subscription_addon.name)
      features = self.subscription_addon.features
      SAAS::SubscriptionEventActions.new(Account.current).handle_feature_data(
        features, SAAS::SubscriptionEventActions::ADD
      )
    end
  end

  def drop_feature_data
    if DROP_DATA_ADDONS.include?(subscription_addon.name)
      features = self.subscription_addon.features
      SAAS::SubscriptionEventActions.new(Account.current).handle_feature_data(
        features, SAAS::SubscriptionEventActions::DROP
      )
    end
  end
end
