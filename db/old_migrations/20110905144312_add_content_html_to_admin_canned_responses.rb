class AddContentHtmlToAdminCannedResponses < ActiveRecord::Migration
  def self.up
    add_column :admin_canned_responses, :content_html, :text, :limit => 16.megabytes + 1
  end

  def self.down
    remove_column :admin_canned_responses, :content_html
  end
end
