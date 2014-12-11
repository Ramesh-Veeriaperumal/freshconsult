class PopulateHtmlFields < ActiveRecord::Migration
  def self.up
    execute "update helpdesk_tickets set description_html=description"
    execute "update helpdesk_notes set body_html=body"
    execute "update admin_canned_responses set content_html=content"
  end

  def self.down
  end
end
