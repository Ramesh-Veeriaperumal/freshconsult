module Mobile::Actions::CannedResponse

	JSON_INCLUDE = {:include => [:folder , :attachments_sharable] }
	
	def to_mob_json
		result = as_json(JSON_INCLUDE)
		result["response"][:folder]["name"] = self.folder.display_name
		result
	end
	
end