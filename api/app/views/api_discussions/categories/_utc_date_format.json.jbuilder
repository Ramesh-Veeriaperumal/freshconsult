json.created_at  item.created_at.try(:utc) if item.created_at
json.updated_at  item.updated_at.try(:utc) if item.updated_at