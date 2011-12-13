class Integrations::InstalledApplication < ActiveRecord::Base
  serialize :configs, Hash
  belongs_to :application, :class_name => 'Integrations::Application'
  belongs_to :account
  attr_protected :application_id, :account_id
  def to_liquid
    return configs[:inputs]
  end
end
