class HyperTrail::Response
  attr_accessor :activities, :meta

  NEXT_KEYWORD = 'next'.freeze
  OBJECT_CLASSES_MAP = {
    'ticket' => 'TicketActivity',
    'post' => 'PostActivity',
    'survey' => 'SurveyActivity',
    'contact_custom_activity' => 'CustomActivity'
  }.freeze

  def initialize
    @activities = []
    @meta = nil
    @ticket_data_transformer = HyperTrail::DataTransformer::TicketDataTransformer.new
    @post_data_transformer = HyperTrail::DataTransformer::PostDataTransformer.new
    @survey_data_transformer = HyperTrail::DataTransformer::SurveyResultDataTransformer.new
  end

  def push(activity)
    content = activity[:content]
    type = content.keys.first
    object_class = Object.const_get("HyperTrail::ActivityObject::#{OBJECT_CLASSES_MAP[type]}")
    object = object_class.new(activity)
    @activities.push(object)
    case type
    when 'ticket'
      @ticket_data_transformer.push(object)
    when 'post'
      @post_data_transformer.push(object)
    when 'survey'
      @survey_data_transformer.push(object)
    else
      return
    end
  end

  def meta_info(link_data)
    if link_data.present?
      link_data.each(&:symbolize_keys!)
      next_page = link_data.find { |link| link[:rel] == NEXT_KEYWORD }
      *, query_param = next_page[:href].split('?')
      @meta = { next_page: query_param } if query_param.present?
    end
  end

  def transform_activities
    @ticket_data_transformer.transform if @ticket_data_transformer.object_ids.present?
    @post_data_transformer.transform if @post_data_transformer.object_ids.present?
    @survey_data_transformer.transform if @survey_data_transformer.object_ids.present?
  end
end
