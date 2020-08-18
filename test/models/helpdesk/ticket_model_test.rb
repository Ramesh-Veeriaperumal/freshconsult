require_relative '../test_helper'
require_relative '../../api/helpers/test_class_methods.rb'
require_relative '../../api/helpers/tickets_test_helper.rb'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class TicketModelTest < ActiveSupport::TestCase
  include AccountHelper
  include UsersHelper
  include TicketsTestHelper
  include EmailHelper
  include TicketFieldsTestHelper
  include TicketStatusTestHelper

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_should_return_requester_language_if_ticket_has_requester
    @account = Account.current
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket(requester_id: user.id)
    assert_equal ticket.requester_language, user.language
  ensure
    ticket.destroy if ticket.present?
  end

  def test_update_email_received_at_ticket
    time = Time.zone.now.to_s
    parsed_date = parse_internal_date(time)
    ticket = Account.current.tickets.last
    ticket.update_email_received_at(parsed_date)
    assert_equal true, ticket.schema_less_ticket.header_info.key?(:received_at)
  end

  def test_update_email_received_at_blank
    ticket = Account.current.tickets.last
    ticket.update_email_received_at(nil)
    assert_equal false, ticket.schema_less_ticket.header_info.key?(:received_at)
  end

  # Replacing the cid for all places using gsub is the fix.
  def test_content_id_for_more_than_one_inline_image_is_same_then_all_images_should_display
    attachment = Helpdesk::Attachment.new
    attachment.attachable_type = 'Ticket::Inline'
    attachment.content_file_name = 'testattach'
    attachment.content_content_type = 'text/binary'
    attachment.content_file_size = 80
    Helpdesk::Ticket.any_instance.stubs(:inline_attachments).returns([attachment])
    ticket = Account.current.tickets.last
    ticket.ticket_body.description_html = "<img src='cid:abc' class='inline-image'> This is content <img src='cid:abc' class='inline-image'> "
    ticket.header_info = { content_ids: { ticket.inline_attachments[0].content_file_name + '0' => 'abc' } }
    ticket.safe_send(:update_content_ids)
    assert_not_equal ticket.ticket_body.description_html, "<img src='cid:abc' class='inline-image'> This is content <img src='cid:abc' class='inline-image'> "
    Helpdesk::Ticket.any_instance.unstub(:inline_attachments)
  end

  def test_ticket_to_xml_with_secure_field
    @account = Account.first.nil? ? create_test_account : Account.first.make_current
    create_custom_field_dn('custom_card_no_test', 'secure_text')
    params = ticket_params_hash
    t = create_ticket(params)
    t.update_attributes("custom_card_no_test_#{Account.current.id}": 'secret_info')
    t.save
    doc = Nokogiri::XML t.to_xml
    xml_to_hash = doc.to_hash
    assert_nil xml_to_hash['helpdesk-ticket']['custom_field']['custom_card_no_test']
  end

  def test_status_name_should_return_translated_custom_status_name_if_translation_record_is_present
    @account = Account.current
    language = 'fr'
    I18n.locale = 'fr'
    ticket_status = create_ticket_status
    ticket = create_ticket
    ticket.status = ticket_status.status_id
    ticket.save!
    trans_label = custom_translation_stub(language, ticket_status.status_id)
    Account.current.stubs(:supported_languages).returns([language])
    assert_equal ticket.translated_status_name, trans_label
  ensure
    I18n.locale = I18n.default_locale
    ticket.destroy if ticket.present?
    ticket_status.destroy if ticket_status.present?
    Account.current.unstub(:supported_languages)
  end

  def test_create_or_update_with_group_id_zero
    @account = Account.first.nil? ? create_test_account : Account.first.make_current
    params = ticket_params_hash(group_id: 0)
    t = create_ticket(params)
    assert_nil t.group_id
    t.group_id = 0
    t.save!
    t.reload
    assert_nil t.group_id
  ensure
    t.destroy if t.present?
  end

  def test_update_ticket_states_when_deadlock_occurs
    @account = Account.first.nil? ? create_test_account : Account.first
    @account.make_current
    ticket = create_ticket(ticket_params_hash)
    assert_nil ticket.ticket_states.resolved_at
    assert_nil ticket.ticket_states.closed_at
    Helpdesk::Ticket.any_instance.stubs(:schema_less_ticket_changed?).returns(true, false)
    Helpdesk::SchemaLessTicket.any_instance.stubs(:save).raises(ActiveRecord::StatementInvalid, 'Deadlock found when trying to get lock')
    ticket.status = 5
    ticket.save
    ticket.reload
    assert_equal true, ticket.ticket_states.resolved_at.is_a?(ActiveSupport::TimeWithZone)
    assert_equal true, ticket.ticket_states.closed_at.is_a?(ActiveSupport::TimeWithZone)
  ensure
    Helpdesk::SchemaLessTicket.any_instance.unstub(:save)
    Helpdesk::Ticket.any_instance.unstub(:schema_less_ticket_changed?)
  end

  private

    def custom_translation_stub(language, status_id)
      field_name = 'status'
      trans_label = 'Translated choice'
      trans_association = language + '_translation'
      tkt_field = @account.ticket_fields.where(name: field_name).first
      tkt_field.safe_send('build_' + trans_association, translations: { 'choices' => { "choice_#{status_id}" => trans_label } }).save!
      trans_label
    end
end
