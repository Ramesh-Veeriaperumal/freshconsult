['tickets_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }

module TimelineTestHelper
  include ApiTicketsTestHelper
  include UsersTestHelper

  def create_timeline_sample_data(sample_user, count = 1, next_page = false)
    sample_data = []
    @result = {}
    @result[:links] = next_page ? [{ 'rel' => 'next', 'href' => 'https://hypertrail-staging.freshworksapi.com/api/v2/activities?start_token=1651334132522601834', 'type' => 'GET' }] : []
    @result[:data] = []
    count.times do
      sample_ticket = create_ticket(requester_id: sample_user.id)
      sample_data.push(sample_ticket)
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
    end
  end

  def timeline_activity_response(sample_user, objects)
    response_pattern = []
    objects.map do |item|
      type = archived?(item) ? 'ticket' : item.class.name.gsub('Helpdesk::', '').downcase
      to_ret = {
        activity: {
          name: "#{type}_create",
          timestamp: item.created_at.try(:utc).try(:iso8601),
          context: object_activity_pattern(item),
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
end
