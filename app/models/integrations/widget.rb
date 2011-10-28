class Integrations::Widget < ActiveRecord::Base
  belongs_to :application
  attr_protected :application_id
end
