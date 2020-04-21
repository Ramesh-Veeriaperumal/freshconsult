['tickets_test_helper.rb', 'users_test_helper.rb', 'surveys_test_helper.rb', 'surveys_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }

module TimelineTestHelper
  include ApiTicketsTestHelper
  include UsersTestHelper
  include SurveysTestHelper

  CLASS_TO_ACTIVITY_NAME_MAP = {
    'Helpdesk::ArchiveTicket' => 'ticket',
    'Helpdesk::Ticket' => 'ticket',
    'Post' => 'post',
    'CustomSurvey::SurveyResult' => 'survey'
  }.freeze

  def create_timeline_sample_data(sample_user, count = 1, next_page = false, survey = nil)
    sample_data = []
    @result = {}
    @result[:links] = next_page ? [{ 'rel' => 'next', 'href' => 'https://hypertrail-staging.freshworksapi.com/api/v2/activities?start_token=1651334132522601834', 'type' => 'GET' }] : []
    @result[:data] = []
    count.times do
      sample_ticket = create_ticket(requester_id: sample_user.id)
      sample_data.push(sample_ticket)
      if survey.present?
        survey_result = create_survey_result(sample_ticket, 103, nil, survey.id)
        sample_data.push(survey_result)
        construct_payload(sample_user, survey_result, 'survey')
      end
      construct_payload(sample_user, sample_ticket, 'ticket')
    end
    count.times do
      test_topic = create_test_topic_with_pubslished_post(Forum.first, true, sample_user)
      sample_data.push(test_topic.posts.first)
      construct_payload(sample_user, test_topic, 'topic')
      test_post = create_test_post(test_topic, true, sample_user)
      sample_data.push(test_post)
      construct_payload(sample_user, test_post, 'post')
    end
    [sample_data, @result]
  end

  def create_custom_timeline_sample_data(sample_user, use_context = true)
    custom_event_data = sample_custom_event(sample_user, use_context)
    @result = {}
    @result[:links] = []
    @result[:data] = [custom_event_data]
    @result
  end

  # Constructing the minimal required payload of hypertrail response
  # Additional payload data will be added for contact timeline V2
  def construct_payload(user, entry, type)
    data = {
      object: {
        type: 'contact',
        id: user.id
      },
      actor: {
        type: 'contact',
        id: user.id
      },
      action_epoch: Faker::Number.number(10)
    }
    case type
    when 'ticket'
      data[:content] = {
        ticket: {
          display_id: entry.display_id,
          id: entry.id
        }
      }
      data[:action] = 'ticket_create'
      @result[:data].push(data)
    when 'post'
      data[:content] = {
        post: {
          id: entry.id
        }
      }
      data[:action] = 'post_create'
      @result[:data].push(data)
    when 'topic'
      data[:content] = {
        post: {
          id: entry.posts.first.id
        }
      }
      data[:action] = 'post_create'
      @result[:data].push(data)
    when 'survey'
      data[:content] = {
        survey: {
          id: entry.id,
          surveyable_type: entry.surveyable_type,
          surveyable_id: entry.surveyable_id,
          survey_id: entry.survey_id
        }
      }
      data[:action] = 'survey_result_create'
      @result[:data].push(data)
    end
  end

  def timeline_activity_response(sample_user, objects)
    response_pattern = []
    objects.map do |item|
      type = CLASS_TO_ACTIVITY_NAME_MAP[item.class.name]
      event_type = type == 'survey' ? 'survey_result_create' : "#{type}_create"
      to_ret = {
        activity: {
          name: event_type,
          timestamp: item.created_at.try(:utc).try(:iso8601),
          context: object_activity_pattern(item, type),
          source: {
            name: 'freshdesk',
            id: Account.current.id
          },
          actor: {
            id: sample_user.id,
            type: 'contact'
          },
          object: {
            type: type
          }
        }
      }
      to_ret[:activity][:object][:id] = type == 'ticket' ? item.display_id : item.id
      response_pattern << to_ret
    end
    response_pattern
  end

  def custom_timeline_activity_response(timeline_data)
    response_pattern = []
    timeline_data[:data].each do |data|
      custom_activity_response = data[:content][:contact_custom_activity]
      next if custom_activity_response.nil?

      to_ret = {
        activity: custom_activity_response[:activity],
        contact: custom_activity_response[:contact]
      }
      response_pattern << to_ret
    end
    response_pattern
  end

  def sample_custom_event(sample_user, use_context)
    ret_hash = {
      'object': {
        'type': 'contact',
        'id': 18_052
      },
      'account_id': sample_user.account_id,
      'action': 'contact_custom_activity',
      'content': {
        'contact_custom_activity': {
          'activity': {
            'actor': {
              'name': 'Freddy',
              'type': 'agent'
            },
            'name': 'order created',
            'source': {
              'id': '8924748010',
              'name': 'shopify'
            },
            'timestamp': 1_580_793_883_031,
            'object': {
              'id': '1234',
              'type': 'call'
            }
          },
          'contact': {
            'id': sample_user.id,
            'name': sample_user.name
          }
        }
      },
      'action_epoch': 1_580_793_883_031
    }
    if use_context
      ret_hash['context'] = {
        'author': 'Shopify',
        'body': nil,
        'path': '450789469',
        'description': 'Received new order 1001 by Bob Norman.',
        'id': 164_748_010,
        'verb': 'confirmed',
        'message': 'Received new order by Bob Norman.',
        'created_at': '2008-01-10T06:00:00-05:00',
        'subject_type': 'Order',
        'subject_id': 450_789_469,
        'arguments': [
          '#1001',
          'Bob Norman'
        ]
      }
    end
    ret_hash
  end
end
