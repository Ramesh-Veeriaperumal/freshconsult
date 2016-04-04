class RemovePhoneAgentAvailabilityFromFeatures < ActiveRecord::Migration

	shard :all

	def up
		Freshfone::Account.find_in_batches(:batch_size => 200) do |freshfone_accounts|
			freshfone_accounts.each do |freshfone_account|
				Sharding.select_shard_of(freshfone_account.account_id) do
					account = freshfone_account.account
					account.make_current
					account.features.phone_agent_availability.destroy if account.features?(:phone_agent_availability)
					Account.reset_current_account
				end
			end
		end
	end

  def down
		Freshfone::Account.find_in_batches(:batch_size => 200) do |freshfone_accounts|
			freshfone_accounts.each do |freshfone_account|
				Sharding.select_shard_of(freshfone_account.account_id) do
					account = freshfone_account.account
					account.make_current
					account.features.phone_agent_availability.create unless account.features?(:phone_agent_availability)
					Account.reset_current_account
				end
			end
		end
	end
end
