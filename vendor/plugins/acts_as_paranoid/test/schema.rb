ActiveRecord::Schema.define(:version => 1) do

  create_table :widgets, :force => true do |t|
    t.column :title, :string, :limit => 50
    t.column :category_id, :integer
    t.column :deleted_at, :timestamp
  end

  create_table :categories, :force => true do |t|
    t.column :widget_id, :integer
    t.column :title, :string, :limit => 50
    t.column :deleted_at, :timestamp
  end

  create_table :categories_widgets, :force => true, :id => false do |t|
    t.column :category_id, :integer
    t.column :widget_id, :integer
  end

end