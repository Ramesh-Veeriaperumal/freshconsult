['tickets_test_helper.rb'].each { |file| require Rails.root.join('test/api/helpers', file) }

module TimelineTestHelper
  include ApiTicketsTestHelper

  def create_timeline_sample_data(sample_user, count = 1)
    sample_data = []
    @result = {}
    @result[:links] = []
    @result[:data] = []
    count.times do
      sample_ticket = create_ticket(requester_id: sample_user.id)
      sample_data.push(sample_ticket)
      construct_payload(sample_ticket, 'ticket')
    end
    count.times do
      test_topic = create_test_topic_with_pubslished_post(Forum.first, true, sample_user)
      sample_data.push(test_topic.posts.first)
      construct_payload(test_topic, 'topic')
      test_post = create_test_post(test_topic, true, sample_user)
      sample_data.push(test_post)
      construct_payload(test_post, 'post')
    end
    [sample_data, @result]
  end

  # Constructing the minimal required payload of hypertrail response
  # Additional payload data will be added for contact timeline V2
  def construct_payload(entry, type)
    data = {}
    data[:content] = {}
    case type
    when 'ticket'
      data[:content][:ticket] = {}
      data[:content][:ticket][:display_id] = entry.display_id
      data[:content][:ticket][:id] = entry.id
      data[:action] = 'ticket_create'
      @result[:data].push(data)
    when 'post'
      data[:content][:post] = {}
      data[:content][:post][:id] = entry.id
      data[:action] = 'post_create'
      @result[:data].push(data)
    when 'topic'
      data[:content][:post] = {}
      data[:content][:post][:id] = entry.posts.first.id
      data[:action] = 'post_create'
      @result[:data].push(data)
    end
  end
end
