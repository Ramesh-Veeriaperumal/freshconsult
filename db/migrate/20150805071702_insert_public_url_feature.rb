class InsertAllowPuburlsFeature < ActiveRecord::Migration
  shard :all
  def up
    Sharding.run_on_all_shards do
      Account.active_accounts.find_in_batches(:batch_size => 300) do |accounts|
        accounts.each do |acc|
          acc.make_current
          acc.features.public_ticket_url.create if not acc.features_included?(:public_ticket_url)
          Account.reset_current_account
        end
      end
    end
  end

  def down
  end
end
