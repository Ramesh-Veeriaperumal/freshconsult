class AddDiscountToBetaUsers < ActiveRecord::Migration
  def self.up
    beta_discount = SubscriptionDiscount.new(:name => 'Beta Users Special', :code => 'KDMSGMPVSKVS', :amount => 10.00, :percent => false, :apply_to_setup => false, :apply_to_recurring => true, :plan_id => 3)
    beta_discount.save!
    Subscription.all.each do |subscription|
      account = subscription.account
      if account.created_at < ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse("2011-06-06 0am")
       subscription.discount = beta_discount
       subscription.save!
      end
    end
  end

  def self.down
    beta_discount = SubscriptionDiscount.find_by_code('KDMSGMPVSKVS')
    beta_discount.destroy
    Subscription.all.each do |subscription|
      account = subscription.account
      if account.created_at < ActiveSupport::TimeZone["Pacific Time (US & Canada)"].parse("2011-06-06 0am")
       subscription.discount = nil
       subscription.save!
      end
    end
  end
end
