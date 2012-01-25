class UpdateCapsuleApp < ActiveRecord::Migration
  @app_name = "freshbooks"
  @widget_name = "freshbooks_timeentry_widget"

  def self.up
    # Update the widget script to use the liquidize filtering for html escaping.
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "{{requester.name}}", "{{requester.name | escape_html}}") WHERE NAME="contact_widget"')
    change_column :installed_applications, :account_id, "bigint unsigned"
    
    #Updates to the domain field for including attributes related to autofill and validation
     capsule_app = Integrations::Application.find_by_name('capsule_crm'); 
     capsule_app.options[:domain][:rel] = "ghostwriter"
     capsule_app.options[:domain][:autofill_text] = ".capsulecrm.com"
     capsule_app.options[:domain][:validator_type] = "domain_validator"
    capsule_app.save
  
  end

  def self.down
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "{{requester.name | escape_html}}", "{{requester.name}}") WHERE NAME="contact_widget"')
    
    capsule_app.options[:domain].delete(:rel)
    capsule_app.options[:domain].delete(:autofill_text)
    capsule_app.options[:domain].delete(:validator_type)
    
    capsule_app.save
  end
end
