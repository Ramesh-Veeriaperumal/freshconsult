# encoding: utf-8
class Mobile::SearchController < SearchController
  before_filter :set_mobile , :only => :search_result
	def search_result
		search  
    respond_to do |format|
      format.mobile {
            json="[" 
            sep=""
            @items.each { |item|
              json << sep+"#{item.to_mob_json_search}"
              sep = ","
            }
            json << "]"
        render :json => json
      }
      end
	end
end