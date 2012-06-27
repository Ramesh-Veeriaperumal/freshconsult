class Helpdesk::TagDrop < BaseDrop
  
  liquid_attributes << :name
  
  def initialize(source)
    super source
  end
end