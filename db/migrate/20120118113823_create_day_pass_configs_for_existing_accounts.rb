class CreateDayPassConfigsForExistingAccounts < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.create_day_pass_config( :available_passes => 3, :auto_recharge => true, 
                                      :recharge_quantity => 10 )
    end
  end

  def self.down
  end
end
