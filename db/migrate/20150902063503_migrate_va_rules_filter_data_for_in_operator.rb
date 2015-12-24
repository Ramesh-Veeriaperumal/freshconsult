class MigrateVaRulesFilterDataForInOperator < ActiveRecord::Migration
  shard :all

  def up
    failed_accounts = []
    Account.reset_current_account
    Account.find_each do |account|
      next if account.nil?
      begin
        account.make_current
        fields = account.fields_with_in_operators

        account.all_va_rules.each do |va_rule|
          changed = false
          va_rule.filter_data.each do |f|
            f.symbolize_keys!
            dropdown_fields = f[:evaluate_on].present? ? fields[f[:evaluate_on]] : fields["ticket"]
            if (f[:operator] == "is" || f[:operator] == "is_not") && (dropdown_fields.include?(f[:name]))
              f[:operator] = (f[:operator] == "is") ? "in" : "not_in"
              f[:value] = [*f[:value]]
              changed = true
            end
          end
          va_rule.save if changed
        end

        account.all_observer_rules.each do |va_rule|
          changed = false
          va_rule.filter_data[:conditions].each do |f|
            f.symbolize_keys!
            dropdown_fields = f[:evaluate_on].present? ? fields[f[:evaluate_on]] : fields["ticket"]
            if (f[:operator] == "is" || f[:operator] == "is_not") && (dropdown_fields.include?(f[:name]))
              f[:operator] = (f[:operator] == "is") ? "in" : "not_in"
              f[:value] = [*f[:value]]
              changed = true
            end
          end
          va_rule.save if changed
        end
      rescue Exception => e
        puts "::::::::::: Migration Failed :: Account id => #{account.id}, Exception => #{e}:::::::::::::"
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    puts failed_accounts.inspect
    failed_accounts
  end

  def down
    failed_accounts = []
    Account.reset_current_account
    Account.find_each do |account|
      next if account.nil?
      begin
        account.make_current
        fields = account.fields_with_in_operators

        account.all_va_rules.each do |va_rule|
          changed = false
          va_rule.filter_data.each do |f|
            f.symbolize_keys!
            dropdown_fields = f[:evaluate_on].present? ? fields[f[:evaluate_on]] : fields["ticket"]
            if (f[:operator] == "in" || f[:operator] == "not_in") && (dropdown_fields.include?(f[:name]))
              f[:operator] = (f[:operator] == "in") ? "is" : "is_not"
              f[:value] = [*f[:value]].first
              changed = true
            elsif (f[:operator] == "in" || f[:operator] == "not_in")
              va_rule.filter_data.delete(f)
              changed = true
            end
          end
          va_rule.save if changed
        end

        account.all_observer_rules.each do |va_rule|
          changed = false
          va_rule.filter_data[:conditions].each do |f|
            f.symbolize_keys!
            dropdown_fields = f[:evaluate_on].present? ? fields[f[:evaluate_on]] : fields["ticket"]
            if (f[:operator] == "in" || f[:operator] == "not_in") && (dropdown_fields.include?(f[:name]))
              f[:operator] = (f[:operator] == "in") ? "is" : "is_not"
              f[:value] = [*f[:value]].first
              changed = true
            elsif (f[:operator] == "in" || f[:operator] == "not_in")
              va_rule.filter_data[:conditions].delete(f)
              changed = true
            end
          end
          va_rule.save if changed
        end
      rescue Exception => e
        puts "::::::::::: Reverting the migration failed :: Account id => #{account.id}, Exception => #{e}:::::::::::::"
        failed_accounts << account.id
      end
      puts failed_accounts.inspect
      failed_accounts
    end
  end

end
