module SegmentConcern
  extend ActiveSupport::Concern

  def handle_segments
    @items = Segments::EsFilter.new(params, controller_name).fetch_result
    response.api_meta = { count: @items.total_entries }
  end

  private

    def validate_and_process_query_hash
      if params[:query_hash].blank? && params[:filter].present?
        current_segment.blank? ? render_errors(filter: :"Invalid filter") : (params[:query_hash] = current_segment.data)
      elsif params[:query_hash].present? && !Segments::FilterDataValidation.new(params[:query_hash], controller_name).valid?
        render_errors(query_hash: :"Invalid query_hash")
      end
    end

    def segments_enabled?
      current_account.segments_enabled?
    end

    def filter_api?
      segments_enabled? && params[:query_hash].present? && params[:state].blank?
    end
end
