# encoding: utf-8
class Integrations::Application < ActiveRecord::Base 
  self.primary_key = :id
  include Integrations::Constants

  serialize :options, Hash
  has_one :custom_widget, 
    :class_name => 'Integrations::Widget',
    :dependent => :destroy
  belongs_to :account
  scope :available_apps, lambda {|account_id| { 
    :conditions => ["account_id  in (?)", [account_id, SYSTEM_ACCOUNT_ID]], 
    :order => :listing_order }}

  has_many :app_business_rules, 
    :class_name => 'Integrations::AppBusinessRule',
    :dependent => :destroy

  has_many :installed_applications, 
    :class_name => 'Integrations::InstalledApplication',
    :dependent => :destroy

  def to_liquid
    JSON.parse(self.to_json)["application"]
  end

  def oauth_url(hash)
    AppConfig['integrations_url'][Rails.env] + 
      Liquid::Template.parse(options[:oauth_url]).render({  'account_id' => hash[:account_id], 'portal_id'  => hash[:portal_id]})
  end

  def widget
    if self.account_id == 0
      Integrations::NativeWidget.find_by(:application_type,self.application_type) #+ self.widgets_data
    else
      self.custom_widget
    end
  end

  def oauth_provider
    case self.name
    when 'google_calendar'
      'google_oauth2'
    else
      self.name
    end
  end

  def user_specific_auth?
    !!self.options[:user_specific_auth]
  end

  def self.install_or_update(app_name, account_id, params={})
    app = Integrations::Application.find_by_name(app_name)
    installed_application = Integrations::InstalledApplication.first(:conditions=>["application_id = ? and account_id=?", app, account_id])
    if installed_application.blank?
      installed_application = Integrations::InstalledApplication.new
      installed_application.application = app
      installed_application.account_id = account_id
    end
    installed_application.configs = {:inputs => params}
    installed_application.save!
    installed_application
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
    custom_app.custom_widget = custom_widget
    installed_application = Integrations::InstalledApplication.new
    installed_application.application = custom_app
    installed_application.account = account
    installed_application[:configs] = {}
    installed_application.save!
  end

  def self.example_app()
    example_app = Integrations::Application.new
    example_app.name = "custom_application"  
    example_app.display_name = "Sample CRM FreshPlug"
    example_app.description = "This is a sample FreshPlug. You can use the script here to understand how FreshPlugs work."
    script = %{

<div id="sample_highrise_widget" title="Sample CRM FreshPlug">
  <div class="content"></div>
  <div class="error"></div>
</div>
<script type="text/javascript">
  CustomWidget.include_js("/javascripts/integrations/sample_highrise.js");
  sample_highrise_options={ domain:"freshdesk3.highrisehq.com", api_key:"c1ca9cc10f8f8a2a8ef422da49d67f51", 
              reqId:"{{requester.id}}", reqName:"{{requester.name | escape_html}}", reqEmail:"{{requester.email}}"}; 
</script>}
    example_app.custom_widget = Integrations::Widget.new(:script => script)
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

  def cti?
    self.application_type == "cti_integration"
  end

  private
    def self.nameify(name)
      "#{name.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}" unless name.blank?
    end

end
