class CompanyDrop < BaseDrop	

	liquid_attributes << :name << :description << :note 

	def initialize(source)
		super source
	end
  
end
