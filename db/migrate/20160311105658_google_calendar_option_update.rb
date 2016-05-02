class GoogleCalendarOptionUpdate < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    app = Integrations::Application.find_by_name("google_calendar")
    app.options[:oauth_url].gsub!("/google_oauth2", "/google_calendar")
    app.save
  end

  def down
    app = Integrations::Application.find_by_name("google_calendar")
    app.options[:oauth_url].gsub!("/google_calendar", "/google_oauth2")
    app.save
  end
end


