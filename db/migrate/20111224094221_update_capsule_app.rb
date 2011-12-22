class UpdateCapsuleApp < ActiveRecord::Migration
  @app_name = "freshbooks"
  @widget_name = "freshbooks_timeentry_widget"

  def self.up
    # Update the widget script to use the liquidize filtering for html escaping.
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "{{requester.name}}", "{{requester.name | escape_html}}") WHERE NAME="contact_widget"')
  end

  def self.down
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "{{requester.name | escape_html}}", "{{requester.name}}") WHERE NAME="contact_widget"')
  end
end
