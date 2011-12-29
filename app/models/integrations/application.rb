class Integrations::Application < ActiveRecord::Base 
  serialize :options, Hash
  has_many :widgets, 
    :class_name => 'Integrations::Widget',
    :dependent => :destroy
  def to_liquid
    Hash.from_xml(self.to_xml)['integrations_application']
  end
end
