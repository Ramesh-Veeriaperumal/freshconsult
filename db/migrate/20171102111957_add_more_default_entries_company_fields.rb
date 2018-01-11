class AddMoreDefaultEntriesCompanyFields < ActiveRecord::Migration
  shard :all

  NON_APPLICABLE_PLANS = ["Basic", "Sprout", "Sprout Classic", "Sprout Jan 17"]

  def self.up
    failed_accounts = []
    invalid_plan_ids = SubscriptionPlan.where(:name => NON_APPLICABLE_PLANS).pluck(:id)
    Account.preload(:subscription).find_each(:batch_size => 500) do |acc|
      begin
        next if invalid_plan_ids.include?(acc.subscription.subscription_plan_id)
        account = acc.make_current
        unless account.has_feature? :tam_default_fields
          account.set_feature(:tam_default_fields) 
          account.save
        end
        CompanyFieldsConstants::company_fields_data(account).each do |field_data|
          CompanyField.create_company_field(field_data, account)
        end
      rescue Exception => e
        puts ":::::::::::#{e}:::::::::::::"
        failed_accounts << account.id
      ensure
        account.company_form.clear_cache
        Account.reset_current_account
      end
    end
    puts failed_accounts.inspect
    failed_accounts
  end

  def self.down
    failed_accounts = []
    invalid_plan_ids = SubscriptionPlan.where(:name => NON_APPLICABLE_PLANS).pluck(:id)
    Account.preload(:subscription).find_each(:batch_size => 500) do |acc|
      begin
        next if invalid_plan_ids.include?(acc.subscription.subscription_plan_id)
        account = acc.make_current
        account.company_form.company_fields.each do |field|
          if (CompanyFieldsConstants::NEW_DEFAULT_FIELDS.include?(field.field_type))
            field.destroy
          end
        end
        if account.has_feature? :tam_default_fields
          account.reset_feature(:tam_default_fields) 
          account.save
        end
      rescue Exception => e
        puts ":::::::::::#{e}:::::::::::::"
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    puts failed_accounts.inspect
    failed_accounts
  end
end
