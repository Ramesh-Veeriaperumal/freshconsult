class PopulatePreferencesInChatSettings < ActiveRecord::Migration
shard :all

def self.up
  Sharding.run_on_all_shards do
   Account.find_in_batches(:batch_size => 200) do |accounts|
    accounts.each do |account|
      chat = account.chat_setting
        unless chat.preferences.blank?
          chat.preferences.merge!({"maximized_title" => chat.maximized_title,"minimized_title" => chat.minimized_title,"welcome_message" => chat.welcome_message,"thank_message" => chat.thank_message,"wait_message" => chat.wait_message})
        else
          chat.update_attributes(:preferences => {"window_color" => "#777777","window_offset" => 30,"window_position" => "Bottom Right","maximized_title" => chat.maximized_title,"minimized_title" => chat.minimized_title,"welcome_message" => chat.welcome_message,"thank_message" => chat.thank_message,"wait_message" => chat.wait_message})
        end 
          chat.save!
      end
    end 
  end
end

def self.down
end
end 