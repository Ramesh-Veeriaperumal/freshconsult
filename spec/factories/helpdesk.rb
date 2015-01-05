if Rails.env.test?
  FactoryGirl.define do
    factory :ticket, :class => Helpdesk::Ticket do |t|
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

    factory :helpdesk_note, :class => Helpdesk::Note do |n|
      n.body Faker::Lorem.paragraph(3)
      n.notable_id 1
      n.notable_type 'Helpdesk::Ticket'
      n.private false
      n.incoming true
    end

    factory :subscription, :class => Helpdesk::Subscription do |s|
    end

    factory :product, :class => Product do |p|
      p.sequence(:name) { |n| "Product#{n}" }
      p.description {Faker::Lorem.paragraph(3)}
    end

    factory :time_sheet, :class => Helpdesk::TimeSheet do |t|
      t.start_time Time.zone.now
      t.time_spent 0
      t.timer_running false
      t.billable false
      t.note Faker::Lorem.sentence(3)
      t.executed_at Time.zone.now
      t.workable_type "Helpdesk::Ticket"
    end

    factory :reminder, :class => Helpdesk::Reminder do |r|
      r.body Faker::Lorem.sentence(3)
      r.deleted false
    end

    factory :flexifield_def_entry, :class => FlexifieldDefEntry do |f|
      f.flexifield_order 3
      f.flexifield_coltype "paragraph"
    end

    factory :ticket_field, :class => Helpdesk::TicketField do |t|
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

    factory :nested_ticket_field, :class => Helpdesk::NestedTicketField do |f|
    end

    factory :picklist_value, :class => Helpdesk::PicklistValue do |f|
    end

    factory :sla_policies, :class => Helpdesk::SlaPolicy do |f|
      f.name "Test Sla Policy"
      f.conditions HashWithIndifferentAccess.new({ :source =>["3"],:company_id =>"" })
    end

    factory :sla_details, :class => Helpdesk::SlaDetail do |f|
    end

    factory :data_export, :class => DataExport do |d|
      d.status 4
      d.token Digest::SHA1.hexdigest "#{Time.now.to_f}"
    end
    
    factory :achieved_quest, :class => AchievedQuest do |d|
      d.quest_id 1
    end

    factory :tag, :class => Helpdesk::Tag do |t|
      t.sequence(:name) { |n| "HelpdeskTag#{n}" }
    end

    factory :agent_group, :class => AgentGroup do |d|
    end

    factory :support_score, :class => SupportScore do |d|
    end

    factory :tag_uses, :class => Helpdesk::TagUse do |d|
    end

    factory :contact_field, :class => ContactField do |t|
      t.description Faker::Lorem.sentence(3)
      t.field_type "custom_paragraph"
      t.position 1
      t.required false
      t.visible_in_portal true
      t.editable_in_portal true 
      t.required_in_portal false
    end

    factory :contact_field_data, :class => ContactFieldData do |d|
    end

    factory :flexifield, :class => Flexifield do |d|
    end
  end
end