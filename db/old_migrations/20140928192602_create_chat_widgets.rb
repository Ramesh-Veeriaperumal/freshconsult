class CreateChatWidgets < ActiveRecord::Migration
  shard :all
  def self.up
    Sharding.run_on_all_shards do
    	create_table :chat_widgets do |t|
    		t.integer :account_id, :limit => 8
        t.integer :product_id, :limit => 8
        t.string  :widget_id
        t.boolean :show_on_portal
        t.boolean :portal_login_required
        t.integer :business_calendar_id, :limit => 8
        t.integer :chat_setting_id, :limit => 8
        t.boolean :active, :default => false
        t.boolean :main_widget

        t.timestamps  
      end
    end
  end

  def self.down
    Sharding.run_on_all_shards do
      drop_table :chat_widgets
    end
  end
end
