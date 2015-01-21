class UpdateGoogleCalendarOptions < ActiveRecord::Migration
  def self.up
  	app = Integrations::Application.find_by_name("google_calendar")
  	app.options[:oauth_url] += "%26user_id%3D{{user_id}}"
  	app.save
  end

  def self.down
  	app = Integrations::Application.find_by_name("google_calendar")
  	app.options[:oauth_url].gsub!("%26user_id%3D{{user_id}}", "")
  	app.save
  end
end
