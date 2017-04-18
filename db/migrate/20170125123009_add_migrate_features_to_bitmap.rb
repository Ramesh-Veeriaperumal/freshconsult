class AddMigrateFeaturesToBitmap < ActiveRecord::Migration
  shard :all
  def migrate(direction)
    self.send(direction)
  end

  def up
    Account.active_accounts.find_in_batches do |accounts|
      accounts.each do |a|
        a.make_current
        bitmap_value = 0
        plan_features_list =  if PLANS[:subscription_plans][a.subscription.subscription_plan.canon_name].nil?
                                ::FEATURES_DATA[:plan_features][:feature_list].keys
                              else
                                ::PLANS[:subscription_plans][a.plan_name][:features]
                              end

        plan_features_list.each do |key|
          bitmap_value = a.set_feature(key)
        end
        a.plan_features = bitmap_value
        a.save
        Account.reset_current_account
      end
    end
  end

  def down
  end
end
