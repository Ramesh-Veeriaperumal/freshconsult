class AddAnswerToPosts < ActiveRecord::Migration
  def self.up
    add_column :posts, :answer, :boolean ,:default => false
  end

  def self.down
    remove_column :posts, :answer
  end
end
