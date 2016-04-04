class SurveyHappyTextConfigurable < ActiveRecord::Migration
def self.up
  	add_column :surveys, :happy_text, :string, :default => "Awesome"
  	add_column :surveys, :neutral_text, :string, :default => "Just Okay"
  	add_column :surveys, :unhappy_text, :string, :default => "Not Good"
  end
 
  def self.down
  	remove_column :surveys, :happy_text
  	remove_column :surveys, :neutral_text
  	remove_column :surveys, :unhappy_text
  end
end
