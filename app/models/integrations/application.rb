class Integrations::Application < ActiveRecord::Base 
  serialize :options, Hash
  has_many :widgets, 
    :class_name => 'Integrations::Widget',
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
end
