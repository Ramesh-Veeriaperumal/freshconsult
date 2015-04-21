json.forum_category do 
   json.(@forum_category, :name, :description, :created_at, :updated_at, :position)
end