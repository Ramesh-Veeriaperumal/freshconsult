class RemoveUnusedColumnsFromChatSettings < ActiveRecord::Migration
  shard :all
  def self.up
    Sharding.run_on_all_shards do
	  	Lhm.change_table :chat_settings, :atomic_switch => true do |m|
	      m.remove_column :preferences
		    m.remove_column :minimized_title
		    m.remove_column :maximized_title
		    m.remove_column :welcome_message
		    m.remove_column :thank_message
		    m.remove_column :wait_message
		    m.remove_column :typing_message
		    m.remove_column :prechat_form
		    m.remove_column :prechat_message
		    m.remove_column :prechat_phone
		    m.remove_column :prechat_mail
		    m.remove_column :proactive_chat
		    m.remove_column :proactive_time
		    m.remove_column :show_on_portal
		    m.remove_column :portal_login_required
		    m.remove_column :business_calendar_id
		    m.remove_column :non_availability_message
		    m.remove_column :prechat_form_name
		    m.remove_column :prechat_form_mail
		    m.remove_column :prechat_form_phoneno
		    m.change_column :display_id, "varchar(255)"
	    end
  	end
  end

  def self.down
    Sharding.run_on_all_shards do
	  	Lhm.change_table :chat_settings, :atomic_switch => true do |m|
		    m.add_column :show_on_portal, :boolean
		    m.add_column :portal_login_required, :boolean
		    m.add_column :business_calendar_id, :bigint
	    end
  	end
  end
end
