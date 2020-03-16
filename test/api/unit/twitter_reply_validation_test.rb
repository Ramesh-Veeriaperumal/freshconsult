require_relative '../unit_test_helper'
require_relative '../helpers/attachments_test_helper'

class TwitterReplyValidationTest < ActionView::TestCase
  include AttachmentsTestHelper

  def self.fixture_path
    Rails.root.join('test', 'api', 'fixtures')
  end

  def test_numericality
    controller_params = { 'twitter_handle_id' => 1, body: 'asdfg', tweet_type: 'mention' }
    item = Helpdesk::Ticket.new
    Helpdesk::Ticket.any_instance.stubs(:twitter?).returns(true)
    conversation = TwitterReplyValidation.new(controller_params, item)
    assert conversation.valid?
    Helpdesk::Ticket.any_instance.unstub(:twitter?)
  end

  def test_body_length
    Helpdesk::Ticket.any_instance.stubs(:twitter?).returns(true)

    item = Helpdesk::Ticket.new
    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(1..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    assert validation.valid?

    item = Helpdesk::Ticket.new
    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(1..10_000)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new(
      { body: Faker::Lorem.characters(rand(281..320)),
        twitter_handle_id: 1,
        tweet_type: 'mention' }, item
    )
    refute validation.valid?
    assert validation.errors.full_messages.include?('Body too_long'), 'Failing when body length exceeds 280'

    validation = TwitterReplyValidation.new({
                                              body: '',
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    refute validation.valid?
    errors = validation.errors.full_messages
    assert(errors.include?('Body blank'))

    Helpdesk::Ticket.any_instance.unstub(:twitter?)
  end

  def test_body_with_url
    Helpdesk::Ticket.any_instance.stubs(:twitter?).returns(true)

    item = Helpdesk::Ticket.new

    long_url = 'https://some.long.url.co/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    short_url = 'http://shorturl.co'
    very_long_url = 'https://verylongurl.co/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(256) + ' ' + long_url,
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new({
                                              body: very_long_url,
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new({
                                              body: long_url + ' ' + short_url + ' ' + very_long_url,
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(258) + long_url,
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Body too_long'), 'Failing when body length exceeds 280'

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10100..10200)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm'
                                            }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Body too_long'), 'Failing when body length exceeds 10000'

  end

  def test_mention
    Helpdesk::Ticket.any_instance.stubs(:twitter?).returns(true)
    item = Helpdesk::Ticket.new
    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(1..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(14..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new({
                                              body: '',
                                              twitter_handle_id: 1,
                                              tweet_type: 'something_else'
                                            }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Tweet type not_included')

    Helpdesk::Ticket.any_instance.unstub(:twitter?)
  end

  def test_twitter_handle
    Helpdesk::Ticket.any_instance.stubs(:twitter?).returns(true)
    item = Helpdesk::Ticket.new
    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(1..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'mention'
                                            }, item)
    assert validation.valid?

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10..140)),
                                              twitter_handle_id: 'asdasd',
                                              tweet_type: 'dm'
                                            }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Twitter handle datatype_mismatch')

    validation = TwitterReplyValidation.new({
                                              body: 'Sample tweet',
                                              tweet_type: 'mention'
                                            }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Twitter handle datatype_mismatch')

    Helpdesk::Ticket.any_instance.unstub(:twitter?)
  end

  def test_with_invalid_twitter_ticket
    item = Helpdesk::Ticket.new
    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm'
                                            }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Ticket not_a_twitter_ticket')
  end

  def get_agent
    @account = Account.first.make_current
    @agent = @account.agents.first.user
    @agent.active = true
    @agent.save!
  end

  def test_with_valid_attachments
    ticket_instance = Helpdesk::Ticket.any_instance
    ticket_instance.stubs(:twitter?).returns(true)
    item = Helpdesk::Ticket.new

    get_agent
    agent_id = @agent.id
    attachment_ids = []
    file = fixture_file_upload('/files/image4kb.png', 'image/png')
    attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: agent_id).id

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm',
                                              attachment_ids: attachment_ids
                                            }, item)

    assert validation.valid?
    ticket_instance.unstub(:twitter?)
  end

  def test_with_invalid_attachments_type
    ticket_instance = Helpdesk::Ticket.any_instance
    ticket_instance.stubs(:twitter?).returns(true)
    item = Helpdesk::Ticket.new

    get_agent
    agent_id = @agent.id
    attachment_ids = []
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: agent_id).id

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm',
                                              attachment_ids: attachment_ids
                                            }, item)

    refute validation.valid?
    assert validation.errors.full_messages.include?('Attachment ids twitter_attachment_file_invalid')
    ticket_instance.unstub(:twitter?)
  end

  # def test_with_duplicate_attachments_type
  #   ticket_instance = Helpdesk::Ticket.any_instance
  #   ticket_instance.stubs(:twitter?).returns(true)
  #   item = Helpdesk::Ticket.new

  #   get_agent
  #   agent_id = @agent.id
  #   attachment_ids = []
  #   file = fixture_file_upload('/files/giphy.gif', 'image/gif')
  #   file2 = fixture_file_upload('/files/image4kb.png', 'image/png')
  #   attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: agent_id).id
  #   attachment_ids << create_attachment(content: file2, attachable_type: 'UserDraft', attachable_id: agent_id).id

  #   validation = TwitterReplyValidation.new({
  #                                             body: Faker::Lorem.characters(rand(10..140)),
  #                                             twitter_handle_id: 1,
  #                                             tweet_type: 'dm',
  #                                             attachment_ids: attachment_ids
  #                                           }, item)

  #   refute validation.valid?
  #   assert validation.errors.full_messages.include?('Attachment ids twitter_attachment_file_unique_type')
  #   ticket_instance.unstub(:twitter?)
  # end

  def test_with_invalid_attachments_limit
    ticket_instance = Helpdesk::Ticket.any_instance
    ticket_instance.stubs(:twitter?).returns(true)
    item = Helpdesk::Ticket.new

    get_agent
    agent_id = @agent.id
    attachment_ids = []
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpeg')
    file2 = fixture_file_upload('/files/image4kb.png', 'image/png')
    attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: agent_id).id
    attachment_ids << create_attachment(content: file2, attachable_type: 'UserDraft', attachable_id: agent_id).id

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm',
                                              attachment_ids: attachment_ids
                                            }, item)

    refute validation.valid?
    assert validation.errors.full_messages.include?('Attachment ids twitter_attachment_file_limit')
    ticket_instance.unstub(:twitter?)
  end

  def test_with_invalid_attachments_size
    ticket_instance = Helpdesk::Ticket.any_instance
    ticket_instance.stubs(:twitter?).returns(true)
    item = Helpdesk::Ticket.new

    get_agent
    agent_id = @agent.id
    attachment_ids = []
    file = fixture_file_upload('/files/image6mb.jpg', 'image/jpeg')
    attachment_ids << create_attachment(content: file, attachable_type: 'UserDraft', attachable_id: agent_id).id

    validation = TwitterReplyValidation.new({
                                              body: Faker::Lorem.characters(rand(10..140)),
                                              twitter_handle_id: 1,
                                              tweet_type: 'dm',
                                              attachment_ids: attachment_ids
                                            }, item)

    refute validation.valid?
    assert validation.errors.full_messages.include?('Attachment ids twitter_attachment_single_file_size')
    ticket_instance.unstub(:twitter?)
  end
end