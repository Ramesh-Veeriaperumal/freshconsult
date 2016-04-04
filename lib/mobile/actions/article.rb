module Mobile::Actions::Article

	JSON_OPTIONS = { 
		:only=> [ :id, :title, :desc_un_html,:description , :status],
		:tailored_json => true
  	}


  def to_mob_json
  	as_json JSON_OPTIONS
  end

  def to_mob_json_search
  	as_json JSON_OPTIONS
  end

end