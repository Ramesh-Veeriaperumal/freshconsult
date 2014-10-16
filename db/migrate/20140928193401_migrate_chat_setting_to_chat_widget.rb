class MigrateChatSettingToChatWidget < ActiveRecord::Migration
  shard :all
  def self.up
    Sharding.run_on_all_shards do
      execute <<-SQL
        INSERT INTO chat_widgets( account_id, show_on_portal, portal_login_required, active, chat_setting_id, main_widget, business_calendar_id, created_at, updated_at) 
                      SELECT cs.account_id, cs.show_on_portal, cs.portal_login_required, cs.active, cs.id, 1, cs.business_calendar_id, cs.created_at, cs.updated_at 
                      FROM chat_settings cs 
                      inner join subscriptions on cs.account_id = subscriptions.account_id 
                                              and subscriptions.state in('free','trial','active');
      SQL
      execute <<-SQL
        INSERT INTO chat_widgets( account_id, product_id, show_on_portal, portal_login_required, active, chat_setting_id, main_widget, business_calendar_id, created_at, updated_at) 
                      SELECT p.account_id, p.id, 0, 0, 0, cs.id, 0, NULL, cs.created_at, cs.updated_at 
                      FROM chat_settings cs 
                      inner join products p on p.account_id = cs.account_id 
                      inner join subscriptions on cs.account_id = subscriptions.account_id 
                                                and subscriptions.state in('free','trial','active');
      SQL
    end
  end

  def self.down
    Sharding.run_on_all_shards do
      execute <<-SQL
        update chat_settings cs 
              inner join chat_widgets cw on 
                cs.id = cw.chat_setting_id and cw.main_widget = true 
              set cs.show_on_portal = cw.show_on_portal, 
                cs.portal_login_required = cw.portal_login_required, 
                cs.business_calendar_id = cw.business_calendar_id
      SQL
    end
  end
end
