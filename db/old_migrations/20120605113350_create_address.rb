class CreateAddress < ActiveRecord::Migration
  def self.up
     create_table :addresses do |t|
      t.string      :first_name
      t.string      :last_name
      t.text        :address1
      t.text        :address2
      t.string      :country
      t.string      :state
      t.string      :city
      t.string      :zip
      t.column      :account_id, "bigint unsigned"
      t.integer     :addressable_id , :limit => 8
      t.string      :addressable_type
      t.timestamps
    end
    
  end

  def self.down
     drop_table :addresses
  end
end
