class CreateSocialStreams < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :social_streams do |t|
      t.string :name
      t.text :description
      t.integer :social_id, :limit => 8
      t.integer :account_id, :limit => 8
      t.text :includes
      t.text :excludes
      t.text :filter
      t.text :data
      t.string :type
      t.timestamps
    end
    
    add_index :social_streams, [:account_id, :social_id], :name => 'index_social_streams_on_account_id_and_social_id'
  end

  def self.down
    drop_table :social_streams
  end
end
