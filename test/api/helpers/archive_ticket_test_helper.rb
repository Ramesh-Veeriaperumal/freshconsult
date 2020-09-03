[ 'group_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require 'webmock/minitest'

module ArchiveTicketTestHelper
  include GroupHelper
  ARCHIVE_BODY = JSON.parse(File.read("#{Rails.root}/test/api/fixtures/archive_ticket_body.json"))['archive_ticket_association']

  def enable_archive_tickets
    @account.enable_ticket_archiving(0)
    yield
  ensure
    disable_archive_tickets
  end

  def disable_archive_tickets
    @account.make_current
    @account.account_additional_settings.additional_settings[:archive_days] = nil
    @account.account_additional_settings.save
    @account.features.archive_tickets.destroy
  end

  def stub_archive_assoc(options = {})
    random_ticket_id = options[:ticket_id] || Faker::Number.number(10)
    display_id = options[:display_id] || Faker::Number.number(10)
    requester_id = options[:requester_id] || Account.current.try(:users).try(:first)
    responder_id = options[:responder_id] || Account.current.try(:technicians).try(:first)
    account_id = options[:account_id] || Account.current.try(:id) || Account.last.try(:id)

    default_options = {
      account_id: account_id,
      requester_id: requester_id,
      responder_id: responder_id,
      display_id: display_id,
      ticket_id: random_ticket_id,
      association_data: {
        'helpdesk_tickets' => {
          'ticket_id' => random_ticket_id,
          'requester_id' => requester_id,
          'responder_id' => responder_id,
          'account_id' => account_id,
          'display_id' => display_id
        },
        'helpdesk_tickets_association' => {
          'ticket_states' => {
            'ticket_id' => random_ticket_id,
            'account_id' => account_id
          }
        }
      }
    }.merge(options)

    Helpdesk::ArchiveTicket
      .any_instance.stubs(:read_from_s3)
      .returns(Helpdesk::ArchiveTicketAssociation.new(ARCHIVE_BODY.merge(default_options)))
    yield
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end

  def convert_ticket_to_archive(ticket)
    freno_stub = stub_request(:get, 'http://freno.freshpo.com/check/ArchiveWorker/mysql/shard_1')
                 .to_return(status: 404, body: '', headers: {})
    Archive::TicketWorker.new.perform(account_id: @account.id, ticket_id: ticket.id)
    remove_request_stub(freno_stub)
  end

  def stub_archive_assoc_for_show(association, _options = {})
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(association)
    yield
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end

  def stub_archive_note_assoc(association)
    Helpdesk::ArchiveNote.any_instance.stubs(:read_from_s3).returns(association)
    yield 
    Helpdesk::ArchiveNote.any_instance.unstub(:read_from_s3)
  end 

  def create_archive_ticket_with_assoc(params = {})
    params_hash = archive_ticket_params_hash(params)
    ticket = params[:create_twitter_ticket] ? create_twitter_ticket(params_hash) : create_ticket(params_hash)
    build_conversations(ticket, params) if params[:create_conversations]
    new_ticket_from_freshcaller_call(ticket) if params[:create_freshcaller_call]
    ticket.updated_at = params[:updated_at] if params[:updated_at].present?
    ticket.save

    @archive_ticket = ticket
    convert_ticket_to_archive(ticket)
    if params[:create_association]
      params_hash = modify_params_hash(ticket, params_hash)
      @archive_association = create_archive_association(ticket, params_hash)
    end
    if params[:create_note_association]
      @archive_note_association = create_note_archive_association
    end
  end

  def build_conversations(ticket, params = {})
    return build_twitter_conversations(ticket) if params[:create_twitter_ticket]

    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    4.times do
      params = {
        user_id: @agent.id,
        ticket_id: ticket.id,
        source: 2, 
        attachments: {
          resource: file
        }
      }      
      create_note(params)
    end
  end

  def build_twitter_conversations(ticket)
    %w[mention dm].map { |tweet_type| create_twitter_note(ticket, tweet_type) }
  end

  def cleanup_archive_ticket ticket, options={}
    @account.archive_tickets.where(display_id:ticket.id).destroy_all
  end

  def create_archive_association(_ticket, params_hash)
    associations = archive_ticket_association_payload(params_hash)
    Helpdesk::ArchiveTicketAssociation.new(associations['archive_ticket_association'])
  end

  def create_note_archive_association
    Helpdesk::ArchiveNoteAssociation.new(archive_note_association_payload)
  end

  def archive_ticket_params_hash(params = {})
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, subject: subject,
                    priority: 2, status: 5, type: 'Problem', responder_id: @agent.id, source: params[:source] || 1, tags: tags,
                    group_id: @create_group.id, created_at: params[:created_at] || 120.days.ago, account_id: @account.id }
    params_hash[:company_id] = params[:company_id] if params[:company_id]
    params_hash[:requester_id] = params[:requester_id] if params[:requester_id]
    params_hash[:tweet_type] = params[:tweet_type] if params[:tweet_type]
    params_hash
  end

  def modify_params_hash(ticket, params_hash)
    params_hash[:description] = ticket.description
    params_hash[:description_html] = ticket.description_html
    params_hash[:due_by] = ticket.due_by.to_datetime.try(:utc).to_s
    params_hash[:frDueBy] = ticket.frDueBy.to_datetime.try(:utc).to_s
    params_hash
  end

  def search_stub_archive_tickets(archive_tickets)
    Freshquery::Response.any_instance.stubs(:errors).returns(nil)
    Freshquery::Response.any_instance.stubs(:items).returns(Search::V2::PaginationWrapper.new(archive_tickets))
    Search::V2::PaginationWrapper.any_instance.stubs(:records).returns(archive_tickets)
    Search::V2::PaginationWrapper.any_instance.stubs(:total_entries).returns(archive_tickets.length)
    yield
    Freshquery::Response.any_instance.unstub(:errors)
    Freshquery::Response.any_instance.unstub(:items)
    Search::V2::PaginationWrapper.any_instance.unstub(:records)
    Search::V2::PaginationWrapper.any_instance.unstub(:total_entries)
  end

  def archive_ticket_association_payload(params = {})
    {
      'archive_ticket_association' => {
        'association_data' => {
          'helpdesk_tickets' => {
            'responder_id' => params[:responder_id] || nil,
            'status' => params[:status] || 2,
            'urgent' => false,
            'source' => params[:source] || 3,
            'spam' => false,
            'deleted' => false,
            'created_at' => params[:created_at],
            'updated_at' => params[:updated_at],
            'trained' => false,
            'account_id' => params[:account_id] || 1,
            'subject' => params[:subject],
            'owner_id' => nil,
            'group_id' => params[:group_id] || nil,
            'due_by' => params[:due_by],
            'frDueBy' => params[:frDueBy],
            'isescalated' => false,
            'priority' => params[:priority] || 1,
            'fr_escalated' => false,
            'to_email' => nil,
            'email_config_id' => nil,
            'cc_email' => {
              'cc_emails' => params[:cc_emails] || [],
              'fwd_emails' => [],
              'bcc_emails' => [],
              'reply_cc' => [],
              'tkt_cc' => []
            }
          },
          'helpdesk_tickets_association' => {
            'schema_less_ticket' => {
              'account_id' => params[:account_id] || 1,
              'product_id' => nil
            },
            'flexifield' => {
              "id":40883277,
              "flexifield_def_id":2,
              "flexifield_set_id":41001919,
              "flexifield_set_type":"Helpdesk::Ticket",
              "created_at":"2014-11-21T14:40:38Z",
              "updated_at":"2014-11-24T09:50:02Z",
              "ffs_01":"No",
              "ffs_04":"Technical support question",
              "ffs_06":"No",
              "ffs_07":"No",
              "ffs_08":"Others",
              "ff_boolean03":false,
              "ff_boolean04":false,
              "account_id":1
            },
            'ticket_states' => {}
          }
        },
        'description' => params[:description],
        'description_html' => params[:description_html]
      }
    }
  end

  def archive_note_association_payload
    {
      'associations_data' => {
        'helpdesk_tickets' => {
          'deleted' => false
        },
        'helpdesk_notes_association' => {
          'schema_less_note' => {
            'from_email' => nil,
            'to_emails' => nil,
            'bcc_emails' => [],
            'cc_emails' => {
              'cc_emails' => []
            }
          }
        }
      }
    } 
  end

  def create_archive_note(note,archive_ticket)
      params = {
        :user_id => note.user_id,
        :archive_ticket_id => archive_ticket.id,
        :note_id => note.id,
        :notable_id => archive_ticket.id,
        :source => note.source,
        :incoming => note.incoming,
        :private => note.safe_send(:private),
        :created_at => note.created_at,
        :updated_at => note.updated_at,
        :deleted  => note.deleted
      }
      test_archive_note = @account.archive_notes.build(params)
      test_archive_note.save
      test_archive_note
  end
end
