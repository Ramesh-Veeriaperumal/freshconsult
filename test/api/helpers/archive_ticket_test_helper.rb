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
    Sidekiq::Testing.inline! do
      Archive::BuildCreateTicket.perform_async(account_id: @account.id, ticket_id: ticket.id)
    end
  end

  def stub_archive_assoc_for_show(association, _options = {})
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(association)
    yield
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
  end

  def create_archive_ticket_with_assoc(params = {})
    params_hash = ticket_params_hash(params)
    ticket = create_ticket(params_hash)
    build_conversations(ticket, params) if params[:create_conversations]
    ticket.updated_at = params[:updated_at] if params[:updated_at].present?
    ticket.save

    @archive_ticket = ticket
    convert_ticket_to_archive(ticket)
    if params[:create_association]
      params_hash = modify_params_hash(ticket, params_hash)
      @archive_association = create_archive_association(ticket, params_hash)
    end
  end

  def build_conversations(ticket, params = {})
    4.times do
      params = {
        user_id: @agent.id,
        ticket_id: ticket.id,
        source: 2
      }
      create_note(params)
    end
  end

  def cleanup_archive_ticket ticket, options={}
    @account.archive_tickets.find_by_display_id(ticket.id).destroy
  end

  def create_archive_association(_ticket, params_hash)
    associations = archive_ticket_association_payload(params_hash)
    Helpdesk::ArchiveTicketAssociation.new(associations['archive_ticket_association'])
  end

  def ticket_params_hash(params = {})
    cc_emails = [Faker::Internet.email, Faker::Internet.email]
    subject = Faker::Lorem.words(10).join(' ')
    email = Faker::Internet.email
    tags = [Faker::Name.name, Faker::Name.name]
    @create_group ||= create_group_with_agents(@account, agent_list: [@agent.id])
    params_hash = { email: email, cc_emails: cc_emails, subject: subject,
                    priority: 2, status: 5, type: 'Problem', responder_id: @agent.id, source: 1, tags: tags,
                    group_id: @create_group.id, created_at: params[:created_at] || 120.days.ago, account_id: @account.id }
    params_hash
  end

  def modify_params_hash(ticket, params_hash)
    params_hash[:description] = ticket.description
    params_hash[:description_html] = ticket.description_html
    params_hash[:due_by] = ticket.due_by.to_datetime.try(:utc).to_s
    params_hash[:frDueBy] = ticket.frDueBy.to_datetime.try(:utc).to_s
    params_hash
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
        'description_html' => params[:description_html],
        'ticket_type' => params[:type] || 'Incident'
      }
    }
  end
end
