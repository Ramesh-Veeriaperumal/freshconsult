class PopulateGoogleAnalytics < ActiveRecord::Migration

  @app_name = "google_analytics"

  def self.up
  	google_analytics = Integrations::Application.create(
        :name => @app_name,
        :display_name => "integrations.google_analytics.label", 
        :description => "integrations.google_analytics.desc", 
        :options => { 
                      :keys_order => [:google_analytics_settings], 
                      :google_analytics_settings => {:type => :custom, 
                          :partial => "/integrations/applications/google_analytics", 
                          :required => false, :label => "integrations.google_analytics.form.google_analytics_settings", 
                          :info => "integrations.google_analytics.form.google_analytics_settings_info" }})
    google_analytics.save
  end

  def self.down
  	Integrations::Application.find(:first, :conditions => {:name => @app_name}).delete
  	execute("DELETE installed_applications FROM installed_applications INNER JOIN applications ON applications.ID=installed_applications.application_id WHERE applications.name='#{@app_name}'")
  end
end

