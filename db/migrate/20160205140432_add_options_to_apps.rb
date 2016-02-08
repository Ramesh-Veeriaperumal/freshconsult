class AddOptionsToApps < ActiveRecord::Migration
  shard :all

  def up
    update_harvest
    update_workflow_max
    update_slack
  end

  def down
    app1 = Integrations::Application.find_by_name("harvest")
    app1.delete(:install, :edit)
    app1.save
    app2 = Integrations::Application.find_by_name("workflow_max")
    app2.delete(:install, :edit)
    app2.save
    app3 = Integrations::Application.find_by_name("slack")
    app3.delete(:install)
    app3.save
  end

  private

  def update_harvest
    app = Integrations::Application.find_by_name("harvest")
    app.options[:install] = {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}}
    app.options[:edit] = {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}}
    app.save!
  end

  def update_workflow_max
    app = Integrations::Application.find_by_name("workflow_max")
    app.options[:install] = {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}}
    app.options[:edit] = {:require_feature => {:notice => 'integrations.no_timesheet_feature', :feature_name => :timesheets}}
    app.save!
  end

  def update_slack
    app = Integrations::Application.find_by_name("slack")
    app.options[:install] = {:deprecated => {:notice => 'integrations.deprecated_message'}}
    app.save!
  end
end
