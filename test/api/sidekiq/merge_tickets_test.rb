# require_relative '../unit_test_helper'
# require_relative '../../test_helper'
# require 'sidekiq/testing'
# require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
# require Rails.root.join('test', 'api', 'helpers', 'time_entries_test_helper.rb')
# require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
# require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')


# class SidekiqMergeTicketsTest < ActionView::TestCase
#   include CreateTicketHelper
#   include ControllerTestHelper
#   include TimeEntriesTestHelper
#   include CoreTicketsTestHelper

#   def setup
#     super
#     initial_setup
#   end

#   def initial_setup
#   	@account = Account.first.make_current
#   	@agent = get_admin.make_current
#   end

#   def test_add_note_to_source_ticket
#   	ticket = create_test_ticket(email: 'sample@freshdesk.com')
#   	note = (0...50).map { ('a'..'z').to_a[rand(26)] }.join
#   	MergeTickets.new.add_note_to_source_ticket(ticket,false,note)
#   	assert_equal true, ticket.notes.last.body_html.include?(note)
#   end

#   def test_move_source_time_sheets_to_target
#   	source_ticket = create_test_ticket(email: 'source@freshdesk.com')
#   	target_ticket = create_test_ticket(email: 'target@freshdesk.com')
#   	time_sheet = create_time_entry(billable: false, ticket_id: source_ticket.id, agent_id: @agent.id, executed_at: 19.days.ago.iso8601)
#   	MergeTickets.new.move_source_time_sheets_to_target(source_ticket,target_ticket.id)
#   	time_sheet.reload
#   	assert_equal target_ticket.id, time_sheet.workable_id
#   end

#   def test_move_source_description_to_target_with_attachment
#   	source_ticket = create_test_ticket(email: 'source@freshdesk.com')
#   	target_ticket = create_test_ticket(email: 'target@freshdesk.com')
#   	source_description = source_ticket.description
#   	file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
#     attachment = {:resource => file,:description => 'temp'}
#     source_ticket.attachments.build(:content => attachment[:resource],
#                                       :description => attachment[:description],
#                                       :account_id => source_ticket.account_id)
#     file.close
#     source_ticket.save
#     Sidekiq::Testing.inline! do
#       MergeTickets.new.move_source_description_to_target(source_ticket,target_ticket,false)
#     end
#     target_ticket_merge_note = target_ticket.notes.last.body_html
#     assert_equal true, target_ticket_merge_note.include?(source_description)
#     assert_equal source_ticket.attachments.last.content_file_name,target_ticket.notes.last.attachments.last.content_file_name
#   end

#   def test_move_source_description_to_target_without_attachment
#   	source_ticket = create_test_ticket(email: 'source@freshdesk.com')
#   	target_ticket = create_test_ticket(email: 'target@freshdesk.com')
#   	source_description = source_ticket.description
#   	MergeTickets.new.move_source_description_to_target(source_ticket,target_ticket,false)
#   	target_ticket_merge_note = target_ticket.notes.last.body_html
#   	assert_equal true, target_ticket_merge_note.include?(source_description)
#   end

#   def test_build_source_description_body_html
#   	source_ticket = create_test_ticket(email: 'source@freshdesk.com')
#   	html = MergeTickets.new.build_source_description_body_html(source_ticket)
#   	assert_equal true, html.include?(source_ticket.description)
#   	assert_equal true, html.include?(source_ticket.subject)
#   end

#   def test_perform_two_tickets
#     # source_ticket = create_test_ticket(email: 'source@freshdesk.com')
#     source_ticket = create_test_ticket_with_notes_and_attachments({email: 'source@freshdesk.com',file: 'attachment.txt'})
#     target_ticket = create_test_ticket(email: 'target@freshdesk.com')
    
#     Sidekiq::Testing.inline! do
#       MergeTickets.new.perform(
#         source_ticket_ids: [source_ticket.display_id],
#         target_ticket_id: target_ticket.id,
#         source_note_private: false,
#         source_note: "test note",
#         target_note_private: false
#       )
#     end
#     validate_perform([source_ticket],target_ticket)
#   end

#   def test_perform_multiple_tickets
#   	source_ticket1 = create_test_ticket_with_notes_and_attachments({email: 'source1@freshdesk.com',file: 'attachment.txt'})
#   	source_ticket2 = create_test_ticket_with_notes_and_attachments({email: 'source2@freshdesk.com',file: 'image33kb.jpg'})
#     target_ticket = create_test_ticket(email: 'target@freshdesk.com')
    
#     Sidekiq::Testing.inline! do
#       MergeTickets.new.perform(
#         source_ticket_ids: [source_ticket1.display_id,source_ticket2.display_id],
#         target_ticket_id: target_ticket.id,
#         source_note_private: false,
#         source_note: "test note",
#         target_note_private: false
#       )
#     end
#     validate_perform([source_ticket1,source_ticket2],target_ticket)
#   end

#   def create_test_ticket_with_notes_and_attachments args
#   	ticket = create_test_ticket(email: args[:email])
#   	note = ticket.notes.build(
#   	  :note_body_attributes => {:body_html => (0...50).map { ('a'..'z').to_a[rand(26)] }.join},
#   	  :private => false,
#   	  :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
#   	  :account_id => @account.id,
#   	  :user_id => @agent.id
#   	)
#   	note.save_note
#   	file = File.new(Rails.root.join("test/api/fixtures/files/#{args[:file]}"))
#     attachment = {:resource => file,:description => 'temp'}
#     ticket.attachments.build(:content => attachment[:resource],
#                                       :description => attachment[:description],
#                                       :account_id => ticket.account_id)
#     file.close
#     ticket.save
#     time_sheet = FactoryGirl.build(:time_sheet, user_id: @agent.id, workable_id: ticket.id, account_id: @account.id, billable: 1, note: '')
#     time_sheet.save
#     ticket
#   end

#   def validate_perform(source_tickets,target_ticket)
#   	target_ticket.reload

#   	all_target_notes = target_ticket.notes
#   	source_tickets.each do |ticket|
#   	  ticket.reload
#   	  flag = false
#       all_target_notes.each do |note|
#         if note.body_html.include?(ticket.display_id.to_s) && note.body_html.include?(ticket.subject) && note.body_html.include?(ticket.description_html) && note.attachments.last.content_file_name == ticket.attachments.last.content_file_name
#           flag = true
#         end
#       end
#       assert flag
#       assert ticket.notes.last.body_html.include?("test note")
#   	end

#   	source_tickets.each do |ticket|
#       refute @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: ticket.id).present?
#     end


#     assert @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: target_ticket.id).present?
#     assert @account.time_sheets.where(workable_type: 'Helpdesk::Ticket', workable_id: target_ticket.id).count == source_tickets.count
#   end
# end