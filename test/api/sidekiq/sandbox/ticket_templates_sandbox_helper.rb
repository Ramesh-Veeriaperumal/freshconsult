['ticket_template_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module TicketTemplatesSandboxHelper
  include TicketTemplateHelper
  MODEL_NAME = Account.reflections["ticket_templates".to_sym].klass.new.class.name
  ACTIONS = ['delete', 'update', 'create']

  def ticket_templates_data(account)
    all_ticket_templates_data = []
    ACTIONS.each do |action|
      all_ticket_templates_data << send("#{action}_ticket_templates_data", account)
    end
    all_ticket_templates_data.flatten
  end

  def create_ticket_templates_data(account)
    ticket_templates_data = []
    #template with parent_child and attachment
    @file = fixture_file_upload('files/attachment.txt', 'text/plain', :binary)
    enable_adv_ticketing(:parent_child_tickets) do
      @agent = account.agents.first
      @groups = account.groups
      @template = create_tkt_template(name: Faker::Name.name,
                                      association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent],
                                      account_id: account.id,
                                      attachments: [{
                                          resource: @file,
                                          description: ''
                                      }],
                                      accessible_attributes: {
                                        access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                      })
      ticket_templates_data << Hash[@template.attributes].merge("model"=>MODEL_NAME, "action"=>"added")
      3.times.each do
        child_template = create_tkt_template(name: Faker::Name.name,
                                             association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child],
                                             account_id: account.id,
                                             attachments: [{
                                              resource: @file,
                                              description: ''
                                            }],
                                             accessible_attributes: {
                                               access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all]
                                             })

        child_template.build_parent_assn_attributes(@template.id)
        child_template.save
        ticket_templates_data << Hash[child_template.attributes].merge("model"=>MODEL_NAME, "action"=>"added")
      end
      return ticket_templates_data
    end
  end

  def update_ticket_templates_data(account)
    update_template_data = []
    parent_template = account.ticket_templates.where(:association_type => Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:parent]).last
    parent_template.description = "modify desc"
    data = parent_template.changes.clone
    parent_template.save
    child_templates = parent_template.child_templates
    update_template_data = child_templates.map { |temp| Hash[temp.attributes].merge("model"=>MODEL_NAME, "action"=>"modified") }
    update_template_data << Hash[data.map {|k,v| [k,v[1]]}].merge("id"=> parent_template.id).merge("model"=>MODEL_NAME, "action"=>"modified")
    update_template_data
  end

  def delete_ticket_templates_data(account)
    template = account.ticket_templates.where(:association_type => Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:child]).last
    template.destroy
    Hash[template.attributes].merge("model"=>MODEL_NAME, "action"=>"deleted")
  end
end