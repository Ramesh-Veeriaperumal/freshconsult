class UpdateGoogleCalendarScript < ActiveRecord::Migration
@widget_name = "google_calendar_widget"

  def self.up
    # Update widget - add ticket_subject to options
    widget = Integrations::Widget.find_by_name(@widget_name)
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
          ticket_subject: "{{ticket.subject | encode_html}}",
          events_list: [{{installed_app.events_list}}],
          oauth_url: "{{installed_app.oauth_url}}"
        };
        CustomWidget.include_js("/javascripts/integrations/google_calendar.js");
      </script>
    )
    widget.save!
  end

  def self.down
    widget = Integrations::Widget.find_by_name(@widget_name)
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
    widget.save!  
  end
end
