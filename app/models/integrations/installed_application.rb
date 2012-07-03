class Integrations::InstalledApplication < ActiveRecord::Base
  serialize :configs, Hash
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to :account
  has_many :integrated_resources, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy
  attr_protected :application_id, :account_id

  after_destroy :delete_google_accounts

  def to_liquid
    configs[:inputs]
  end

  def method_missing(meth_name, *args, &block)
    matched = /configs_(.*)/.match(meth_name.to_s)
    if matched.blank?
      super
    else
      input_key = matched[1]
      input_values = self[:configs][:inputs] unless self[:configs].blank?
      input_values[input_key] unless input_values.blank?
    end
  end

  private
  	def delete_google_accounts
	    if self.application.name == "google_contacts"
	      Rails.logger.info "Deleting all the google accounts corresponding to this account."
	      Integrations::GoogleAccount.destroy_all ["account_id = ?", self.account]
	    end
  	end
end
