if Rails.env.test?
  Factory.define :ticket, :class => Helpdesk::Ticket do |t|
    t.status 2
    t.urgent 0
    t.deleted 0
    t.to_email Faker::Internet.email
    t.ticket_type "Question"
    t.sequence(:display_id) { |n| n }
    t.trained 0
    t.isescalated 0
    t.priority 1
    t.subject Faker::Lorem.sentence(3)
    t.description Faker::Lorem.paragraph(3)
    t.cc_email({:cc_emails => [], :fwd_emails => [], :reply_cc => []}.with_indifferent_access)
    t.created_at Time.now
  end

  Factory.define :helpdesk_note, :class => Helpdesk::Note do |n|
    n.body Faker::Lorem.paragraph(3)
    n.notable_id 1
    n.notable_type 'Helpdesk::Ticket'
    n.private false
    n.incoming true
  end

  Factory.define :subscription, :class => Helpdesk::Subscription do |s|
  end

  Factory.define :product, :class => Product do |p|
    p.sequence(:name) { |n| "Product#{n}" }
    p.description {Faker::Lorem.paragraph(3)}
  end

  Factory.define :time_sheet, :class => Helpdesk::TimeSheet do |t|
    t.start_time Time.zone.now
    t.time_spent 0
    t.timer_running false
    t.billable false
    t.note Faker::Lorem.sentence(3)
    t.executed_at Time.zone.now
    t.workable_type "Helpdesk::Ticket"
  end

  Factory.define :reminder, :class => Helpdesk::Reminder do |r|
    r.body Faker::Lorem.sentence(3)
    r.deleted false
  end

  Factory.define :flexifield_def_entry, :class => FlexifieldDefEntry do |f|
    f.flexifield_order 3
    f.flexifield_coltype "paragraph"
  end

  Factory.define :ticket_field, :class => Helpdesk::TicketField do |t|
    t.description Faker::Lorem.sentence(3)
    t.active true
    t.field_type "custom_paragraph"
    t.position 3
    t.required false
    t.visible_in_portal true
    t.editable_in_portal true 
    t.required_in_portal false
    t.required_for_closure false
  end

  Factory.define :nested_ticket_field, :class => Helpdesk::NestedTicketField do |f|
  end

  Factory.define :picklist_value, :class => Helpdesk::PicklistValue do |f|
  end

  Factory.define :sla_policies, :class => Helpdesk::SlaPolicy do |f|
    f.name "Test Sla Policy"
    f.conditions HashWithIndifferentAccess.new({ :source =>["3"],:company_id =>"" })
  end

  Factory.define :sla_details, :class => Helpdesk::SlaDetail do |f|
  end

  Factory.define :data_export, :class => DataExport do |d|
    d.status 4
    d.token Digest::SHA1.hexdigest "#{Time.now.to_f}"
  end
  
  Factory.define :achieved_quest, :class => AchievedQuest do |d|
    d.quest_id 1
  end

  Factory.define :tag, :class => Helpdesk::Tag do |t|
    t.sequence(:name) { |n| "HelpdeskTag#{n}" }
  end

  Factory.define :agent_group, :class => AgentGroup do |d|
  end

  Factory.define :support_score, :class => SupportScore do |d|
  end

  Factory.define :tag_uses, :class => Helpdesk::TagUse do |d|
  end

  Factory.define :contact_field, :class => ContactField do |t|
    t.description Faker::Lorem.sentence(3)
    t.field_type "custom_paragraph"
    t.position 1
    t.required false
    t.visible_in_portal true
    t.editable_in_portal true 
    t.required_in_portal false
  end

  Factory.define :contact_flexifield, :class => ContactFlexifield do |d|
  end

  Factory.define :flexifield, :class => Flexifield do |d|
  end
end