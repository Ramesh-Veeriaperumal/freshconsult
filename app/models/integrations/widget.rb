class Integrations::Widget < ActiveRecord::Base
  self.primary_key = :id
  belongs_to :application, :class_name =>'Integrations::Application'
  attr_protected :application_id
  serialize :options, Hash
  include Integrations::WidgetCore
end
