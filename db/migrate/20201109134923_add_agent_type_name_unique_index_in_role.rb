# frozen_string_literal: true

class AddAgentTypeNameUniqueIndexInRole < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :roles, atomic_switch: true do |m|
      m.remove_index(['account_id', 'name'], 'index_roles_on_account_id_and_name')
      m.add_unique_index(['account_id', 'agent_type', 'name'], 'index_roles_on_account_id_and_agent_type_and_name')
    end
  end

  def down
    Lhm.change_table :roles, atomic_switch: true do |m|
      m.remove_index(['account_id', 'agent_type', 'name'], 'index_roles_on_account_id_and_agent_type_and_name')
      m.add_unique_index(['account_id', 'name'], 'index_roles_on_account_id_and_name')
    end
  end
end
