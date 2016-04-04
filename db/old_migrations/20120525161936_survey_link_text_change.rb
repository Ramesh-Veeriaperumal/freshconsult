class SurveyLinkTextChange < ActiveRecord::Migration
  def self.up
  	execute("update surveys set link_text='Please let us know your opinion on our support experience.'")
  end

  def self.down  	
  end
end
