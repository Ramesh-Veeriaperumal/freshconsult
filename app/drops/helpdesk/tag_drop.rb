class Helpdesk::TagDrop < BaseDrop
  
  self.liquid_attributes += [:name]
  
  def initialize(source)
    super source
  end
end