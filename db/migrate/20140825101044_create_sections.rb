class CreateSections < ActiveRecord::Migration
  shard :all
  def self.up
  	create_table :helpdesk_sections do |t|  
      t.integer     :account_id,  :limit => 8
      t.integer     :form_id,    :limit => 8
      t.string      :label
      t.text        :options
      t.timestamps
    end

    add_index :helpdesk_sections, [:account_id, :label], 
              :name => 'index_helpdesk_section_fields_on_account_id_and_label'
  end

  def self.down
  	drop_table :helpdesk_sections
  end
end
