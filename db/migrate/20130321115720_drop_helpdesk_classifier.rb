class DropHelpdeskClassifier < ActiveRecord::Migration
	shard :none
  def self.up
  	drop_table :helpdesk_classifiers
  end

  def self.down
  end
end
