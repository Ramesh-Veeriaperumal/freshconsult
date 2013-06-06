class CreateElasticsearchIndex < ActiveRecord::Migration
  def self.up
    create_table :elasticsearch_indices do |t|
      t.string "name", :null => false
      t.timestamps
    end

    add_index "elasticsearch_indices", ["name"], :name => "index_elasticsearch_indices_on_name", :unique => true
  end

  def self.down
    drop_table :elasticsearch_indices
  end
end
