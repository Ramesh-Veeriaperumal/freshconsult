class DropElasticsearchIndex < ActiveRecord::Migration
  shard :none
  def self.up
  	drop_table :elasticsearch_indices
  end

  def self.down
  	create_table :elasticsearch_indices do |t|
      t.string "name", :null => false
      t.timestamps
    end

    add_index "elasticsearch_indices", ["name"], :name => "index_elasticsearch_indices_on_name", :unique => true
  end
end
