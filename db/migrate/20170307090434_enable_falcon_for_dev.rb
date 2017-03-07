class EnableFalconForDev < ActiveRecord::Migration

  shard :all

  def up
    puts "*" * 100
    puts "Enabling FalconUI for Dev env"
    Account.reset_current_account
    Account.find_each do |account|
      next if account.nil?
      account.make_current
      account.launch(:falcon)
      puts "Launched FalconUI for Account ##{account.id}"
    end
  end

  def down
    puts "Disabling FalconUI for Dev env"
    Account.reset_current_account
    Account.find_each do |account|
      next if account.nil?
      account.make_current
      account.rollback(:falcon)
      puts "Rolled back FalconUI for #{account.id}"
    end
  end

  def migrate(direction)
    self.send(direction)
  end

end
