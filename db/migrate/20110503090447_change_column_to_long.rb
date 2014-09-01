class ChangeColumnToLong < ActiveRecord::Migration
  def self.up
      columns_to_change.each do |c|
      change_column c[0], c[1], :integer, :limit => 8
    end
  end

def self.columns_to_change
    [
      [ :customers,                 :import_id ],      
      [ :flexifield_def_entries,    :import_id ],     
      [ :forum_categories,          :import_id ],  
      [ :forums,                    :import_id ],
      [ :groups,                    :import_id ],
      [ :helpdesk_tickets,          :import_id ],     
      [ :solution_categories,       :import_id ], 
      [ :solution_folders,          :import_id ],
      [ :solution_articles,         :import_id ],     
      [ :topics,                    :import_id ],     
      [ :users,                     :import_id ]
      
    ]
  end
  def self.down
  end
end
