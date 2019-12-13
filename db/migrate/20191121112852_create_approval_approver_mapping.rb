class CreateApprovalApproverMapping < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :helpdesk_approver_mappings do |t|
      t.integer :account_id, limit: 8, null: false
      t.integer :approval_id, limit: 8, null: false
      t.integer :approver_id, limit: 8, null: false
      t.integer :approval_status, limit: 8, null: false
      t.timestamps
      t.text :comments
    end

    add_index :helpdesk_approver_mappings, [:account_id, :approval_id], name: 'index_approval_mapping_on_acc_id_approval_id'
    add_index :helpdesk_approver_mappings, [:account_id, :approval_id, :approver_id], unique: true, name: 'index_approval_mapping_on_acc_id_approval_id_approver_id'
  end

  def down
    drop_table :helpdesk_approver_mappings
  end
end
