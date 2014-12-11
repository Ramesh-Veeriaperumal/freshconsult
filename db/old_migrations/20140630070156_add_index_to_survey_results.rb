class AddIndexToSurveyResults < ActiveRecord::Migration
	shard :all
	def self.up
		Lhm.change_table :survey_results, :atomic_switch => true do |m|
	  		m.add_index [:surveyable_id, :surveyable_type]
		end
	end

	def self.down
		Lhm.change_table :survey_results, :atomic_switch => true do |m|
	  		m.remove_index [:surveyable_id, :surveyable_type]
		end
	end
end
