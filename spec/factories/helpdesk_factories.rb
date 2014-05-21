if ENV["RAILS_ENV"] == "test"
  Factory.define :ticket, :class => Helpdesk::Ticket do |t|
    t.status 2
    t.urgent 0
    t.deleted 0
    t.to_email Faker::Internet.email
    t.ticket_type "Question"
    t.display_id 1
    t.trained 0
    t.isescalated 0
    t.priority 1
    t.subject Faker::Lorem.sentence(3)
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
end