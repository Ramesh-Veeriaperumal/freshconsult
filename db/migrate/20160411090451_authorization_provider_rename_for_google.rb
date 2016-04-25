class AuthorizationProviderRenameForGoogle < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    limit_size = 1000
    last_row_id = 0
    while(true) do
      rows = Authorization.limit(limit_size).order("id").where('id > ?', last_row_id).all
      to_change_rows = []
      if rows.present?
        rows.each do |row|
          to_change_rows.push(row.id) if row.provider == "oauth"
          last_row_id = row.id
        end
      end
      Authorization.where("id in (?)", to_change_rows).update_all({:provider => "google"}) if to_change_rows.present?
      break if rows.blank? || rows.size < 1000
    end
  end

  def down
    limit_size = 1000
    last_row_id = 0
    while(true) do
      rows = Authorization.limit(limit_size).order("id").where('id > ?', last_row_id).all
      to_change_rows = []
      if rows.present?
        rows.each do |row|
          to_change_rows.push(row.id) if row.provider == "google"
          last_row_id = row.id
        end
      end
      Authorization.where("id in (?)", to_change_rows).update_all({:provider => "oauth"}) if to_change_rows.present?
      break if rows.blank? || rows.size < 1000
    end
  end

end