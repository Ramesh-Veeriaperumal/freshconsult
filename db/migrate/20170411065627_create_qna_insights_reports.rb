class CreateQnaInsightsReports < ActiveRecord::Migration
  shard :all
  def up
    create_table :qna_insights_reports, :force => true do |t|
      t.column      :user_id, "bigint unsigned"
      t.column      :account_id, "bigint unsigned"
      t.text        :recent_questions
      t.text        :insights_config_data
      t.timestamps
    end
   add_index :qna_insights_reports , [:account_id, :user_id], :name => 'index_qna_insights_reports_on_account_id_and_user_id'
  end

  def down
    drop_table :qna_insights_reports
  end
end
