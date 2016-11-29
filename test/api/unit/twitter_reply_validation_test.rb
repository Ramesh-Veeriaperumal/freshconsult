require_relative '../unit_test_helper'

class TwitterReplyValidationTest < ActionView::TestCase

  def test_numericality
    controller_params = { 'twitter_handle_id' => 1,  body: 'asdfg', tweet_type: 'mention' }
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
    
    validation = TwitterReplyValidation.new({
        body: Faker::Lorem.characters(rand(141..240)),
        twitter_handle_id: 1,
        tweet_type: 'mention'
      }, item)
    refute validation.valid?
    assert validation.errors.full_messages.include?('Body too_long'), 'Failing when body length exceeds 140'
    
    validation = TwitterReplyValidation.new({
        body: '',
        twitter_handle_id: 1,
        tweet_type: 'mention'
      }, item)
    refute validation.valid?
    errors =  validation.errors.full_messages
    assert(errors.include?('Body blank'))
    
    Helpdesk::Ticket.any_instance.unstub(:twitter?)
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
          twitter_handle_id: "asdasd",
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

end
