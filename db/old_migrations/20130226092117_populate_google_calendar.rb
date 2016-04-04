class PopulateGoogleCalendar < ActiveRecord::Migration
@app_name = "google_calendar"
@widget_name = "google_calendar_widget"

  def self.up
    # Add new application called google_calendar
    app = Integrations::Application.new
    app.name = @app_name
    app.display_name = "integrations.google_calendar.label"  
    app.description = "integrations.google_calendar.desc"
    app.options = {
      :direct_install => true,
      :oauth_url => "/auth/google_oauth2?origin=pid%3D{{portal_id}}%26app_name%3Dgoogle_calendar",
      :user_specific_auth => true,
      :auth_config => {
        :clazz => 'Integrations::GoogleCalendarEmailFinder',
        :method => 'find_and_store_user_registered_email'
      }
    }
    app.save!

    puts "INSERTED google_calendar APP ID #{app.id}"

    # Add new widget under Google Calender app
    widget = app.widgets.first || app.widgets.build
    widget.name = @widget_name
    widget.description = 'google_calendar.widgets.google_calendar.description'
    widget.script = %(
      <link href="/stylesheets/pattern/pattern.css" media="screen" rel="stylesheet" type="text/css">
      <script src="/javascripts/pattern/bootstrap-typeahead.js" type="text/javascript"></script>

      <div id="google_calendar_widget"">
        <div class="content">
          <div class="title">
            <span>
              Google Calendar
            </span>

            <a href="#" class="pull-right" id="add_event_link">Add Event</a><br>
            <span id="gcal-email-container" class="hide">{{installed_app.user_registered_email}}</span>
            <br>
            <a href="{{installed_app.oauth_url}}" id="gcal-change-account-link" class="hide">Change</a>
          </div>
          <div class="gcal-content-body">
            <div id="gcal-older-events-link-container" class="hide"><span class="arrow-right" id="gcal-older-events-arrow"></span><a id="gcal-older-events-link" href="#older_events">Older Events</a></div> 
            <div id="google_calendar_events_container"></div>
          </div>
        </div>
      </div>

      <script type="text/javascript">
        var google_calendar_options={
          domain:"www.googleapis.com",
          application_id: {{application.id}},
          oauth_token:"{{installed_app.user_access_token}}",
          ticket_id: parseInt('{{ticket.id}}'),
          events_list: [{{installed_app.events_list}}],
          oauth_url: "{{installed_app.oauth_url}}"
        };
        CustomWidget.include_js("/javascripts/integrations/google_calendar.js");
      </script>
    )
    widget.options = {'display_in_pages' => ["helpdesk_tickets_show_page_side_bar"]}
    widget.save!

  end

  def self.down
    execute("DELETE FROM applications WHERE name='google_calendar'")
    execute("DELETE FROM widgets WHERE name='google_calendar_widget'")
  end
end
