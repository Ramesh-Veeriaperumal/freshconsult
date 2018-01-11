class AddIndexAgentOrGroupsAndAccountCreatedRatingToSureyResults < ActiveRecord::Migration
	shard :all

	def migrate(direction)
    self.send(direction)
  end

  def up
		Lhm.change_table :survey_results, :atomic_switch => true do |m|
			m.add_index [:account_id, :agent_id, :created_at, :rating], 'index_survey_results_on_acc_agent_id_created_at_rating'
			m.add_index [:account_id, :group_id, :created_at, :rating], 'index_survey_results_on_acc_group_id_created_at_rating'
		end
  end

  def down
		Lhm.change_table :survey_results, :atomic_switch => true do |m|
			m.remove_index [:account_id, :agent_id, :created_at, :rating], 'index_survey_results_on_acc_agent_id_created_at_rating'
			m.remove_index [:account_id, :group_id, :created_at, :rating], 'index_survey_results_on_acc_group_id_created_at_rating'
		end
  end
end
