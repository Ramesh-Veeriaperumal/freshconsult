require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class UndoSendWorkerTest < ActionView::TestCase
  def setup
    @account = Account.first.make_current
    @account.launch(:undo_send)
  end

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
  end

  def undo_send_args
    {
      account_id: Account.current.id,
      user_id: User.current.id,
      ticket_id: ticket.display_id,
      note_basic_attributes:
        {
          'id' => nil,
          'body' => nil,
          'user_id' => User.current.id,
          'source' => 0,
          'incoming' => false,
          'private' => false,
          'created_at' => Time.now.utc,
          'updated_at' => nil,
          'deleted' => false,
          'notable_id' => ticket.display_id,
          'notable_type' => 'Helpdesk::Ticket',
          'account_id' => Account.current.id,
          'body_html' => nil
        },
      note_schema_less_associated_attributes:
        {
          from_email: reply_note_params_hash[:from_email],
          to_emails: [User.current.email],
          cc_emails: [],
          bcc_emails: [],
          header_info: nil,
          category: nil,
          response_time_in_seconds: nil,
          response_time_by_bhrs: nil,
          email_config_id: 1,
          subject: nil,
          last_modified_user_id: nil,
          last_modified_timestamp: nil,
          sentiment: nil,
          dynamodb_range_key: nil,
          failure_count: nil,
          import_id: nil,
          support_email: reply_note_params_hash[:from_email],
          changes_for_observer: nil,
          disable_observer_rule: nil,
          nscname: nil,
          disable_observer: nil,
          send_survey: nil,
          include_surveymonkey_link: nil,
          quoted_text: nil,
          skip_notification: nil,
          last_note_id: ticket.notes.last.id
        },
      attachment_details: [],
      inline_attachment_details: [],
      publish_solution_later: nil
    }
  end

  def reply_note_params_hash
    body = Faker::Lorem.paragraph
    email = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    bcc_emails = [Faker::Internet.email, Faker::Internet.email, "\"#{Faker::Name.name}\" <#{Faker::Internet.email}>"]
    email_config = @account.email_configs.where(active: true).first || create_email_config
    params_hash = { body: body, cc_emails: email, bcc_emails: bcc_emails, from_email: email_config.reply_email }
    params_hash
  end

  def test_undo_send_reply
    User.current = Account.current.users.first
    args = HashWithIndifferentAccess.new(undo_send_args)
    Tickets::UndoSendWorker.new.perform(args)
    assert_equal 0, ::Tickets::UndoSendWorker.jobs.size
  ensure
    @account.rollback(:undo_send)
  end
end
