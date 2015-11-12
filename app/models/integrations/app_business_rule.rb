class Integrations::AppBusinessRule < ActiveRecord::Base 
  self.primary_key = :id
  belongs_to :va_rule, :class_name => 'VaRule', :dependent => :destroy
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
  belongs_to_account
  attr_protected :application_id, :va_rule_id
end
