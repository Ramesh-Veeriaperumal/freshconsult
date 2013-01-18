class ShowHighriseInContactsPage < ActiveRecord::Migration
  def self.up
  	app = Integrations::Application.find_by_name('highrise')
  	widget = app.widgets.first
  	widget.options = {'display_in_pages' => ["contacts_show_page_side_bar"]}
  	widget.save!
  end

  def self.down
  	app = Integrations::Application.find_by_name('highrise')
  	widget = app.widgets.first
  	widget.options = nil
  	widget.save!
  end
end
