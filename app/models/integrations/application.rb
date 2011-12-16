class Integrations::Application < ActiveRecord::Base 
  serialize :options, Hash
  has_many :widgets, 
    :class_name => 'Integrations::Widget',
    :dependent => :destroy
end
