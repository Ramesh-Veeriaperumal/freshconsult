module Mobile::Actions::Article

	JSON_OPTIONS = { 
		:only=> [ :id, :title, :desc_un_html,:description , :status],
		:tailored_json => true
  	}

  def to_mob_json
  	hash = as_json(JSON_OPTIONS)
		hash["article"]["id"] = self.parent_id
		hash
  end

  def to_mob_json_search
		hash = as_json(JSON_OPTIONS)
		hash["article"]["id"] = self.parent_id
		hash
  end

end