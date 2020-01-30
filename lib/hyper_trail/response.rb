class HyperTrail::Response
  NEXT_KEYWORD = 'next'.freeze
  TRANSFORMATION_CLASSES = ['TicketDataTransformer', 'PostDataTransformer'].freeze

  def initialize(response)
    @data = response
    @activities = response[:activities]
    @meta = nil

    link_data = response[:link]
    if link_data.present?
      link_data.each(&:symbolize_keys!)
      next_page = link_data.find { |link| link[:rel] == NEXT_KEYWORD }
      *, query_param = next_page[:href].split('?')
      @meta = { next_page: query_param } if query_param.present?
    end
  end

  def fetch_transformed_response
    return @activities if @activities.blank?

    TRANSFORMATION_CLASSES.each do |transformation_class|
      transformer_class = Object.const_get("HyperTrail::ActivityDataTransformer::#{transformation_class}")
      transformer_object = transformer_class.new(@activities)
      transformer_object.construct_transformed_timeline_activities
    end

    @activities.reject! { |activity| activity[:activity][:context].blank? }
    @activities
  end

  def fetch_meta_info
    @meta
  end
end
