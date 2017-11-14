class AddMoreDefaultEntriesCompanyFields < ActiveRecord::Migration
  include CompanyFieldsConstants
  shard :all

  VALID_PLANS = ["Blossom", "Garden", "Estate", "Forest", "Blossom Jan 17", "Garden Jan 17", "Estate Jan 17", "Forest Jan 17"]

  DEFAULT_FIELDS =
    [
      { :name               => "health_score", 
        :label              => "Health score"},

      { :name               => "account_tier", 
        :label              => "Account tier" },

      { :name               => "renewal_date", 
        :label              => "Renewal date" },

      { :name               => "industry", 
        :label              => "Industry" }
    ]

  def self.up
    failed_accounts = []
    valid_plan_ids = SubscriptionPlan.where(:name => VALID_PLANS).pluck(:id)
    Account.preload(:subscription).find_each(:batch_size => 500) do |acc|
      if acc.id == 11
        begin
          next if acc.subscription.state == 'suspended' && valid_plan_ids.exclude?(acc.subscription.subscription_plan_id)
          account = acc.make_current
          unless account.has_feature? :tam_default_fields
            account.set_feature(:tam_default_fields) 
            account.save
          end
          company_fields_data(account).each do |field_data|
            field_name = field_data.delete(:name)
            column_name = field_data.delete(:column_name)
            deleted = field_data.delete(:deleted)
            unless field_name == "renewal_date"
              field_data[:custom_field_choices_attributes] = TAM_FIELDS_DATA["#{field_name}_data"]
            end
            field = CompanyField.new(field_data)
            field.name = field_name
            field.column_name = column_name
            field.deleted = deleted
            field.company_form_id = account.company_form.id
            field.save
          end
        rescue Exception => e
          puts ":::::::::::#{e}:::::::::::::"
          failed_accounts << account.id
        ensure
          account.company_form.clear_cache
          Account.reset_current_account
        end
      end
    end
    puts failed_accounts.inspect
    failed_accounts
  end

  def self.down
    failed_accounts = []
    valid_plan_ids = SubscriptionPlan.where(:name => VALID_PLANS).pluck(:id)
    Account.preload(:subscription).find_each(:batch_size => 500) do |acc|
      if acc.id == 11
        begin
          next if acc.subscription.state == 'suspended' && valid_plan_ids.exclude?(acc.subscription.subscription_plan_id)
          account = acc.make_current
          if account.has_feature? :tam_default_fields
            account.set_feature(:tam_default_fields) 
            account.save
          end
          account.company_form.company_fields.each do |field|
            if (NEW_DEFAULT_FIELDS.include?(field.field_type))
              field.destroy
            end
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

  def self.company_fields_data account
    existing_fields_count = account.company_form.fields.length
    DEFAULT_FIELDS.each_with_index.map do |f, i|
      {
        :name               => f[:name],
        :column_name        => 'default',
        :label              => f[:label],
        :deleted            => 0,
        :field_type         => :"default_#{f[:name]}",
        :position           => existing_fields_count + i + 1,
        :required_for_agent => f[:required_for_agent] || 0,
        :field_options      => f[:field_options] || {},
      }
    end
  end
end
