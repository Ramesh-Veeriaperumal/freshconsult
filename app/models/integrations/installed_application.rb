class Integrations::InstalledApplication < ActiveRecord::Base
  serialize :configs, Hash
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to :account
  has_many :integrated_resources, :class_name => 'Integrations::IntegratedResource', :dependent => :destroy
  attr_protected :application_id, :account_id
  def to_liquid
    configs[:inputs]
  end
end
