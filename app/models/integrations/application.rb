class Integrations::Application < ActiveRecord::Base 
  include Integrations::Constants

  serialize :options, Hash
  has_many :widgets, 
    :class_name => 'Integrations::Widget',
    :dependent => :destroy
  belongs_to :account
  named_scope :available_apps, lambda {|account_id| { 
    :conditions => ["account_id  in (?)", [account_id, SYSTEM_ACCOUNT_ID]], 
    :order => :listing_order }}
  after_destroy :destroy_installed_apps

  has_many :app_business_rules, 
    :class_name => 'Integrations::AppBusinessRule',
    :dependent => :destroy

  def to_liquid
    Hash.from_xml(self.to_xml)['integrations_application']
  end

  def self.install_or_update(app_name, account_id, params={})
    app = Integrations::Application.find_by_name(app_name)
    installed_application = Integrations::InstalledApplication.first(:conditions=>["application_id = ? and account_id=?", app, account_id])
    if installed_application.blank?
      installed_application = Integrations::InstalledApplication.new
      installed_application.application = app
      installed_application.account_id = account_id
    end
    installed_application.configs = {:inputs => params}.to_hash
    installed_application.save!
  end

  def self.create_and_install(application_params, widget_script, display_in_pages, account)
    custom_app = Integrations::Application.new(application_params)
    app_name = self.nameify(application_params[:display_name])
    custom_app.name = "#{app_name}_#{account.id}"
    custom_app.options = {}
    custom_app.account = account
    custom_widget = Integrations::Widget.new
    custom_widget.name = "#{app_name}_widget_#{account.id}"
    custom_widget.description = ""
    custom_widget.display_in_pages_option = display_in_pages
    custom_widget.script = widget_script
    custom_app.widgets.push(custom_widget)
    installed_application = Integrations::InstalledApplication.new
    installed_application.application = custom_app
    installed_application.account = account
    installed_application[:configs] = {}
    installed_application.save!
  end

  def self.example_app()
    example_app = Integrations::Application.new
    example_app.name = "custom_application"  
    example_app.display_name = "Sample CRM Widget"
    example_app.description = "This is a sample widget.  You can use the script here to understand how the custom widget works."
    script = %{
<div id="capsule_widget" domain="freshdeskdemo.capsulecrm.com" title="Sample CRM Widget">
  <div class="content"></div>
</div>
<script type="text/javascript">
  CustomWidget.include_js("/javascripts/capsule_crm.js");
  capsuleBundle={ t:"b43cff831b56cec58fa8cd95c21b47f5", reqId:"{{requester.id}}", 
                  reqName:"{{requester.name | escape_html}}", reqOrg:"{{requester.company_name}}", 
                  reqPhone:"{{requester.phone}}", reqEmail:"{{requester.email}}"}; 
</script>}
    example_app.widgets.push Integrations::Widget.new(:script => script)
    # example_app.options = {
    #   :keys_order => [:name, :widget_script],
    #   :name => { :type => :text, :required => true, :label => "integrations.custom_application.form.widget_title", :default_value => "My App"},
    #   :widget_script => { :type => :paragraph, :required => true, :label => "integrations.custom_application.form.widget_script", :default_value => script}
    # }
    example_app
  end

  def system_app?
    self.account_id == SYSTEM_ACCOUNT_ID
  end

  private
    def self.nameify(name)
      "#{name.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}" unless name.blank?
    end

    def destroy_installed_apps
      unless self.account == SYSTEM_ACCOUNT_ID
        installed_apps = Integrations::InstalledApplication.find_by_account_id_and_application_id(self.account.id, self.id)
        installed_apps.destroy unless installed_apps.blank?
      end
    end
end
