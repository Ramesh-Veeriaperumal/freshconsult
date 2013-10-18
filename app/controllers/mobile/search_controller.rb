# encoding: utf-8
class Mobile::SearchController < Search::HomeController
  before_filter :set_native_mobile , :only => :search_result
  def search_result
    search(searchable_classes)
    respond_to do |format|
      format.nmobile {
            json="[" 
            sep=""
            @search_results.each { |item|
              json << sep+"#{item.to_mob_json_search}"
              sep = ","
            }
            json << "]"
        render :json => json
      }
      end
	end
end