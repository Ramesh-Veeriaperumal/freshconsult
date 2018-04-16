class AddIndexTagIdTaggableTypeToHelpdeskTagUses < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :helpdesk_tag_uses, :atomic_switch => true do |m|
      m.add_index  [:account_id, :tag_id, :"taggable_type(20)"], "index_tag_use_on_acc_tag_taggable_type"
    end
  end

  def down
    Lhm.change_table :helpdesk_tag_uses, :atomic_switch => true do |m|
      m.remove_index [:account_id, :tag_id, :"taggable_type(20)"], "index_tag_use_on_acc_tag_taggable_type"
    end
  end

end