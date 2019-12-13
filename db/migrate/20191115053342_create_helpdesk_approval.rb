class CreateHelpdeskApproval < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :helpdesk_approvals do |t|
      t.integer :id, limit: 8, null: false
      t.integer :user_id, limit: 8, null: false
      t.integer :account_id, limit: 8, null: false
      t.string :approvable_type, null: false
      t.integer :approvable_id, limit: 8, null: false
      t.integer :approval_status, limit: 8, null: false
      t.integer :approval_type, limit: 8
      t.timestamps
      t.integer :int_01, limit: 8
      t.integer :int_02, limit: 8
      t.text :text_01
      t.text :text_02
    end

    add_index :helpdesk_approvals, [:account_id, :approvable_type, :approvable_id], name: 'index_hd_approvals_on_acc_id_approvable_id_and_type'
    add_index :helpdesk_approvals, [:account_id, :user_id, :approvable_type, :approvable_id, :approval_status], name: 'index_hd_approvals_on_acc_id_user_id_appr_id_appr_type_apprstats'
  end

  def down
    drop_table :helpdesk_approvals
  end
end
