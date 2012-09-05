class UpdateApplications < ActiveRecord::Migration
  def self.up
    add_column :applications, :account_id, :integer, :default => 0
    add_column :widgets, :options, :text
    widgets = Integrations::Widget.find(:all, :conditions=>["name in (?)", ['contact_widget', 'sugarcrm_widget', 'salesforce_widget']])
    widgets.each {|wid|
      wid.display_in_pages_option = ["contacts_show_page_side_bar"]
      wid.save!
    }
  end

  def self.down
    remove_column :widgets, :options
    remove_column :applications, :account_id
    # delete all the added custom apps
  end
end
