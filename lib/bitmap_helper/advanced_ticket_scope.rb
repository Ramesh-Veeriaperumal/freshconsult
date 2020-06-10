require 'bitmap_helper/base_bitmap_feature'

class AdvancedTicketScope < BaseBitmapFeature
  def on_revoke_feature(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      delete_all_contributing_agent_groups(account)
      Account.reset_current_account
    end
  end

  private

    def delete_all_contributing_agent_groups(account)
      account.contribution_agent_groups.find_each(batch_size: 300, &:destroy)
    end
end
