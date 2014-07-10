class DeleteSurveyLinkFeature < ActiveRecord::Migration
  def self.up
  	execute("delete from features where type='SurveyLinksFeature'")
  	add_column :survey_handles, :rated, :boolean, :default => false
  end

  def self.down
  	 remove_column :survey_handles, :rated
  end
end
