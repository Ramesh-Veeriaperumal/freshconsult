class Integrations::Application < ActiveRecord::Base
  self.primary_key = :id
  include Integrations::Constants

  attr_accessible :name, :display_name, :description, :listing_order, :options, :account_id, :application_type, :dip

  serialize :options, Hash
  has_one :custom_widget, 
    :class_name => 'Integrations::Widget',
    :dependent => :destroy
  belongs_to :account

  scope :available_apps, ->(account_id){
    where(["account_id  in (?)", [account_id, SYSTEM_ACCOUNT_ID]])
    .order(:listing_order)
  }

  scope :freshplugs, lambda {|account_id| 
    where(:account_id => account_id , 
          :application_type => Integrations::Constants::FRESHPLUG)
    .includes([:installed_applications]) }

  has_many :app_business_rules, 
    :class_name => 'Integrations::AppBusinessRule',
    :dependent => :destroy

  has_many :installed_applications, 
    :class_name => 'Integrations::InstalledApplication',
    :dependent => :destroy

  concerned_with :presenter

  def to_liquid
    JSON.parse(self.to_json)["application"]
  end

  def oauth_url(hash, app_name = nil)
    user_specific_apps = ["box", "google_calendar"]
    app_config = {
      'account_id' => hash[:account_id],
      'portal_id' => hash[:portal_id], 
      'falcon_enabled' => hash[:falcon_enabled]
    }
    app_config.merge!('user_id' => hash[:user_id]) if user_specific_apps.include? app_name
    AppConfig['integrations_url'][Rails.env] + 
      Liquid::Template.parse(options[:oauth_url]).render(app_config)
  end

  def widget
    if self.freshplug?
      self.custom_widget
    else
      Integrations::NativeWidget.find_by(:application_type, self.application_type)
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

  def freshplug?
    self.account_id != Integrations::Constants::SYSTEM_ACCOUNT_ID && 
      self.application_type == Integrations::Constants::FRESHPLUG
  end

  def user_specific_auth?
    !!self.options[:user_specific_auth]
  end

  def self.install_or_update(app_name, account_id, params={})
    app = Integrations::Application.find_by_name(app_name)
    installed_application = Integrations::InstalledApplication.find_by_application_id_and_account_id(app.id, account_id)
    if installed_application.blank?
      installed_application = Integrations::InstalledApplication.new
      installed_application.application = app
      installed_application.account_id = account_id
    end
    installed_application.set_configs(params)
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
    custom_app
  end

  def self.example_app()
    example_app = Integrations::Application.new
    example_app.name = "custom_application"  
    example_app.display_name = "Sample CRM custom app"
    example_app.description = "This is a sample custom app. You can use the script here to understand how custom apps work."
    script = %{<div id="sample_highrise_widget" title="Sample CRM custom app">
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

  def slack?
    self.application_type == "slack"
  end

  def zohocrm?
    self.application_type == "zohocrm"
  end

  def shopify?
    self.application_type == Integrations::Constants::APP_NAMES[:shopify]
  end

  private
    def self.nameify(name)
      "#{name.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}" unless name.blank?
    end

end
