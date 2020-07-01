if Rails.env.test?
  FactoryGirl.define do
    factory :ticket, :class => Helpdesk::Ticket do |t|
      status 2
      urgent 0
      deleted 0
      to_email Faker::Internet.email
      ticket_type "Question"
      sequence(:display_id) { |n| n }
      trained 0
      isescalated 0
      priority 1
      subject Faker::Lorem.sentence(3)
      cc_email(Helpdesk::Ticket.default_cc_hash.with_indifferent_access)
      created_at Time.now
    end

    factory :helpdesk_note, :class => Helpdesk::Note do |n|
      body Faker::Lorem.paragraph(3)
      notable_id 1
      notable_type 'Helpdesk::Ticket'
      private false
      incoming true
    end

    factory :subscription, :class => Helpdesk::Subscription do |s|
    end

    factory :trial_subscription, :class => TrialSubscription do |s|
    end

    factory :product, :class => Product do |p|
      sequence(:name) { |n| "Product#{n}" }
      description {Faker::Lorem.paragraph(3)}
    end

    factory :time_sheet, :class => Helpdesk::TimeSheet do |t|
      start_time Time.zone.now
      time_spent 0
      timer_running false
      billable false
      note Faker::Lorem.sentence(3)
      executed_at Time.zone.now
      workable_type "Helpdesk::Ticket"
    end

    factory :reminder, :class => Helpdesk::Reminder do |r|
      body Faker::Lorem.sentence(3)
      deleted false
    end

    factory :flexifield_def_entry, :class => FlexifieldDefEntry do |f|
      flexifield_order 3
      flexifield_coltype "paragraph"
    end

    factory :ticket_field, :class => Helpdesk::TicketField do |t|
      description Faker::Lorem.sentence(3)
      active true
      field_type "custom_paragraph"
      position 3
      required false
      visible_in_portal true
      editable_in_portal true 
      required_in_portal false
    end

    factory :nested_ticket_field, :class => Helpdesk::NestedTicketField do |f|
    end

    factory :picklist_value, :class => Helpdesk::PicklistValue do |f|
    end

    factory :ticket_status, :class => Helpdesk::TicketStatus do |f|
    end

    factory :helpdesk_source, :class => Helpdesk::Source do |f|
    end

    factory :section, :class => Helpdesk::Section do |s|
    end

    factory :section_picklist_mapping, :class => Helpdesk::SectionPicklistValueMapping  do |s|
    end

    factory :section_field, :class => Helpdesk::SectionField do |s|
    end

    factory :sla_policies, :class => Helpdesk::SlaPolicy do |f|
      name "Test Sla Policy"
      conditions HashWithIndifferentAccess.new({ :source =>["3"],:company_id =>"" })
    end

    factory :sla_details, :class => Helpdesk::SlaDetail do |f|
    end

    factory :data_export, :class => DataExport do |d|
      status 4
      token Digest::SHA1.hexdigest "#{Time.now.to_f}"
    end
    
    factory :achieved_quest, :class => AchievedQuest do |d|
      quest_id 1
    end

    factory :tag, :class => Helpdesk::Tag do |t|
      sequence(:name) { |n| "HelpdeskTag#{n}" }
    end

    factory :agent_group, :class => AgentGroup do |d|
    end

    factory :support_score, :class => SupportScore do |d|
    end

    factory :tag_uses, :class => Helpdesk::TagUse do |d|
    end

    factory :contact_field, :class => ContactField do |t|
      description Faker::Lorem.sentence(3)
      field_type "custom_paragraph"
      position 1
      required false
      visible_in_portal true
      editable_in_portal true 
      required_in_portal false
    end

    factory :contact_field_data, :class => ContactFieldData do |d|
    end

    factory :flexifield, :class => Flexifield do |d|
    end

    factory :ticket_templates, :class => Helpdesk::TicketTemplate do |t|
      sequence(:name) { |n| "Testing Ticket Template#{n}" }
      description { Faker::Lorem.sentence(10) }
    end
    
    factory :subscription_payment, :class => SubscriptionPayment do |s|
    end

    factory :report_filters, :class => Helpdesk::ReportFilter do |t|
    end

    factory :scheduled_tasks, :class => Helpdesk::ScheduledTask do |t|
    end

    factory :scheduled_exports, :class => ScheduledExport do |t|
    end
  end
end
