module CreateTicketHelper
  def create_test_ticket(params)
    a=Account.current
    user_ids = a.technicians.map(&:id)
    group_ids = a.groups.map(&:id)
    o = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
    sub = (0...50).map { o[rand(o.length)] }.join
    desc = (0...50).map { o[rand(o.length)] }.join
    cc_emails = params[:cc_emails] || []
    fwd_emails = params[:fwd_emails] || []
    ticket = Helpdesk::Ticket.new(
        :account_id => a.id,
        :subject => sub,
        :ticket_body_attributes => {:description => desc,
                          :description_html => desc},
        :email => params[:email],
        :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
        :source => params[:source] || Helpdesk::Source::PHONE,
        :group_id => params[:group_id],
        :created_at => params[:created_at] || Time.now,
        cc_email: Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
      )
      random_group_id = group_ids.sample
      ticket.group_id ||= random_group_id
      g=a.groups.find(random_group_id)
      ticket.responder_id = g.agents.map(&:id).sample
      ticket.priority = params[:priority] || [1,2,3,4].sample
      statuses_list = Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
      statuses_list = statuses_list.delete_if {|st| [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(st)}
      ticket.status ||= statuses_list.keys.sample
      ticket.ticket_type = Account.current.ticket_types_from_cache.collect { |g| [g.value, g.value]}.to_h.keys.sample
      ticket.save_ticket!
      ticket
  end

  def create_sla_policy(group = nil)
    @account = Account.current
    h = {
      :name => Faker::Lorem.words(5),
      :conditions => 
          { :group_id => [group.try(:id)] }, 
            :escalations => 
            { 
              :reminder_response => { "1" => { :time=> "-1800", :agents_id => ["-1"] } },
              :reminder_resolution => { "1" => { :time=> "-1800", :agents_id => ["-1"] } },
              :response => { "1" => {:time=>"0", :agents_id=>["-1"] } }, 
              :resolution => { "1" => { :time=>"0", :agents_id=>["-1"] }
            }
          }
      }
    
    sla=@account.sla_policies.new(h)
    sla.is_default=false

    sla_details_hash = {
      "0" => {
        :name => "SLA for urgent priority", 
        :priority => "4", :response_time=>"900", "resolution_time"=>"900", 
        :override_bhrs => "false", :escalation_enabled => "1"
        }, 
      "1" => {
        :name=>"SLA for high priority", 
        :priority=>"3",:response_time=>"900", "resolution_time"=>"900", 
        :override_bhrs=>"false", :escalation_enabled => "1"
        },
      "2" => { 
        :name=>"SLA for medium priority", 
        :priority=>"2", :response_time=>"900", "resolution_time"=>"900", 
        :override_bhrs=>"false", :escalation_enabled => "1"
        }, 
      "3" => {
        :name => "SLA for low priority", 
        :priority => "1",:response_time=>"900", "resolution_time"=>"900", 
        :override_bhrs => "false", :escalation_enabled => "1"
        }
    }
    sla_details_hash.deep_symbolize_keys!
    sla_details_hash.each_value {|sd|  sla.sla_details.build(sd) } 
    sla.save  
  end

end