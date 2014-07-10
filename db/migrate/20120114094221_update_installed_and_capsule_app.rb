class UpdateInstalledAndCapsuleApp < ActiveRecord::Migration
  def self.up
    # Some data type changes in installed_applications table.
    change_column :installed_applications, :configs, :text 
    change_column :installed_applications, :account_id, "bigint unsigned"

    # Update the widget script to use the liquidize filtering for html escaping.
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "{{requester.name}}", "{{requester.name | escape_html}}") WHERE NAME="contact_widget"')
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "id=\"content\"", "class=\"content\"") WHERE NAME="contact_widget"')

    #Updates to the domain field for including attributes related to autofill and validation
    capsule_app = Integrations::Application.find_by_name('capsule_crm'); 
    capsule_app.options[:domain][:rel] = "ghostwriter"
    capsule_app.options[:domain][:autofill_text] = ".capsulecrm.com"
    capsule_app.options[:domain][:validator_type] = "domain_validator"
    capsule_app.save
  end

  def self.down
    execute('UPDATE widgets SET SCRIPT=REPLACE(SCRIPT, "{{requester.name | escape_html}}", "{{requester.name}}") WHERE NAME="contact_widget"')

    capsule_app = Integrations::Application.find_by_name('capsule_crm');
    capsule_app.options[:domain].delete(:rel)
    capsule_app.options[:domain].delete(:autofill_text)
    capsule_app.options[:domain].delete(:validator_type)
    capsule_app.save

    change_column :installed_applications, :configs, :string
  end
end
