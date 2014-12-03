if Rails.env.test?
  FactoryGirl.define do
    factory :ticket, :class => Helpdesk::Ticket do
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
      description Faker::Lorem.paragraph(3)
      cc_email({:cc_emails => [], :fwd_emails => []}.with_indifferent_access)
      created_at Time.now
    end

    factory :helpdesk_note, :class => Helpdesk::Note do
      body Faker::Lorem.paragraph(3)
      notable_id 1
      notable_type 'Helpdesk::Ticket'
      private false
      incoming true
    end

    # TODO-RAILS3
     factory :subscription, :class => Helpdesk::Subscription do
     end

    factory :product, :class => Product do
      sequence(:name) { |n| "Product#{n}" }
      description {Faker::Lorem.paragraph(3)}
    end

    factory :time_sheet, :class => Helpdesk::TimeSheet do
      start_time Time.zone.now
      time_spent 0
      timer_running false
      billable false
      note Faker::Lorem.sentence(3)
      executed_at Time.zone.now
      workable_type "Helpdesk::Ticket"
    end

    factory :reminder, :class => Helpdesk::Reminder do
      body Faker::Lorem.sentence(3)
      deleted false
    end

    factory :flexifield_def_entry, :class => FlexifieldDefEntry do
      flexifield_order 3
      flexifield_coltype "paragraph"
    end

    factory :ticket_field, :class => Helpdesk::TicketField do
      description Faker::Lorem.sentence(3)
      active true
      field_type "custom_paragraph"
      position 3
      required false
      visible_in_portal true
      editable_in_portal true 
      required_in_portal false
      required_for_closure false
    end

    # TODO-RAILS3
     factory :nested_ticket_field, :class => Helpdesk::NestedTicketField do
     end

     factory :picklist_value, :class => Helpdesk::PicklistValue do
     end

    factory :note, :class => Helpdesk::Note do
      deleted 0
      incoming 0
      private 1
    end

    factory :sla_policies, :class => Helpdesk::SlaPolicy do
      name "Test Sla Policy"
      conditions HashWithIndifferentAccess.new({ :source =>["3"],:company_id =>"" })
    end

    # TODO-RAILS3
     factory :sla_details, :class => Helpdesk::SlaDetail do
     end

    factory :data_export, :class => DataExport do
      status 4
      token Digest::SHA1.hexdigest "#{Time.now.to_f}"
    end
    
    factory :achieved_quest, :class => AchievedQuest do
      quest_id 1
    end

    factory :tag, :class => Helpdesk::Tag do
      sequence(:name) { |n| "HelpdeskTag#{n}" }
    end

    factory :support_score, :class => SupportScore do
    end

    factory :tag_uses, :class => Helpdesk::TagUse do
    end

     #TODO-RAILS3
    factory :agent_group, :class => AgentGroup do
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

    factory :contact_flexifield, :class => "ContactFlexifield" do |d|
    end

    factory :flexifield, :class => Flexifield do |d|
    end
  end

  
end