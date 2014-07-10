class Integrations::AppBusinessRule < ActiveRecord::Base 
  belongs_to :va_rule, :class_name => 'VARule', :dependent => :destroy
  belongs_to :application, :class_name => 'Integrations::Application'
  attr_protected :application_id, :va_rule_id
end
