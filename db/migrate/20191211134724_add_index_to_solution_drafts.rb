class AddIndexToSolutionDrafts < ActiveRecord::Migration
  shard :all
  def migrate(direction)
    send(direction)
    end

  def up
    Lhm.change_table :solution_drafts, atomic_switch: true do |m|
      m.add_index [:account_id, :article_id], 'index_solution_drafts_on_account_id_article_id'
    end
  end

  def down
    Lhm.change_table :solution_drafts, atomic_switch: true do |m|
      m.remove_index [:account_id, :article_id], 'index_solution_drafts_on_account_id_article_id'
    end
  end
end
