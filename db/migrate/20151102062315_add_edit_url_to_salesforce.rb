class AddEditUrlToSalesforce < ActiveRecord::Migration
  shard :all
  def up
    app = Integrations::Application.find_by_name("salesforce")
    app.options.delete(:pre_install)
    app.options[:edit_url] = "/integrations/salesforce/edit"
    app.save
  end

  def down
    app = Integrations::Application.find_by_name("salesforce")
    app.options[:pre_install] = true
    app.options.delete(:edit_url)
    app.save
  end
end
