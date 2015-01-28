class FreshfoneWhitelistCountries < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table "freshfone_whitelist_countries", :force => true do |t|
    t.integer "account_id",               :limit => 8
    t.string  "country",				  :limit => 50
 	end 

 	add_index(:freshfone_whitelist_countries, [:account_id, :country], 
      :name => "index_ff_whitelist_countries_on_account_id_and_country")
  end
end
