#should we have to move thsi outside as it will be useful for all other view also?
json.created_at  item.created_at.try(:utc) if item.created_at
json.updated_at  item.updated_at.try(:utc) if item.updated_at