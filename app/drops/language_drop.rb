class LanguageDrop < BaseDrop
    
  self.liquid_attributes += [:code, :id, :name]
  
  def initialize(source)
    super source
  end
end