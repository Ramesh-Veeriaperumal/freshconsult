module AutomationDelegatorTestHelper

  CUSTOM_FIELDS_TYPES = %w(text paragraph checkbox number)

  def ticket_condition
    hash = [{ field_name: "ticket_type", operator: "in", value: ["Refund"] },
            { field_name: "test_custom_dropdown", operator: "in", value: ["Get Smart"] }]
    hash
  end

  def company_contion
    company = [{ field_name: "health_score", operator: "in", value: ["Happy"] },
               { field_name: "account_tier", operator: "in", value: ["Enterprise"] },
               { field_name: "cf_test_custom_text", operator: "is", value: "fcvgbhjn" },
               { field_name: "cf_test_custom_paragraph", operator: "is", value: "fcvgbhjn" },
               { field_name: "cf_test_custom_checkbox", operator: "is", value: "selected" },
               { field_name: "cf_test_custom_number", operator: "is", value: 32 }]
    company
  end

  def contact_condition
    hash = [{ field_name: "cf_test_custom_text", operator: "is", value: "fcvgbhjn" },
            { field_name: "cf_test_custom_paragraph", operator: "is", value: "fcvgbhjn" },
            { field_name: "cf_test_custom_checkbox", operator: "is", value: "selected" },
            { field_name: "cf_test_custom_number", operator: "is", value: 32 }]
    hash
  end

  def get_custom_contact_fields
    CUSTOM_FIELDS_TYPES.each do |field_type|
      cf_params = cf_params(type: field_type, field_type: "custom_#{field_type}",
                            label: "test_custom_#{field_type}", editable_in_signup: 'true')
      create_custom_contact_field(cf_params)
    end
  end

  def get_custom_company_fields
    CUSTOM_FIELDS_TYPES.each do |field_type|
      cf_params = company_params({ type: field_type, field_type: "custom_#{field_type}",
                                   label: "test_custom_#{field_type}" })
      create_custom_company_field(cf_params)
    end
  end

  def condition(type)
    case type
    when "ticket"
      { condition_set_1: { match_type: "all", ticket: ticket_condition}}
    when "company"
      { condition_set_1: { match_type: "all", company: company_contion}}
    when "contact"
      { condition_set_1: { match_type: "all", contact: contact_condition}}
    end
  end

  def valid_rule(performer, event, condition, action)
    hash = { name: "Sample Dispatch'r 77 rule", position: 1, active: false,
        performer: performer, events: event, conditions: condition(condition), actions: action }
    hash
  end

  def valid_performer
    hash = { type:  1, members: [1] }
    hash
  end

  def invalid_performer
    hash = { type: 8, members: [987, 34] }
    hash
  end

  def valid_event
    hash = [
        { field_name: "test_custom_country", from: "Australia", to: "USA",
          from_nested_field: { level2: { field_name: "test_custom_state", value: "New South Wales" },
                               level3: { field_name: "test_custom_city", value: "Sydney" }},
          to_nested_field: { level2: { field_name: "test_custom_state", value: "California" },
                             level3: { field_name: "test_custom_city", value: "Burlingame" }}},
    { field_name: "ticket_type", from: "Question", to: "" }, { field_name: "status", from: "--", to: 3 },
        { field_name: "status", from: "--", to: 3 }, { field_name: "priority", from: "--", to: 4 },
        { field_name: "group_id", from: 4, to: 2 }]
    hash
  end

  def valid_action
    hash = [
        { field_name: "group_id", value: 4 },
        { field_name: "cf_number", value: 8 },
        { field_name: "cf_decimal", value: 9.9 },
        { field_name: "ticket_type", value: "Question" },
        { field_name: "status", value: 3 },
        { field_name: "priority", value: 4 },
        { field_name: "test_custom_dropdown", value: "Get Smart" },
        { field_name: "test_custom_country", value: "USA",
          nested_fields: {
              level2: { field_name: "test_custom_state", value: "California" },
              level3: { field_name: "test_custom_city", value: "Burlingame" }}}]
    hash
  end

  def create_tags_data(account)
    count = 1
    3.times do
      account.tags.create(name: "test#{count}")
      count += 1
    end
  end

  def create_products(account)
    count = 1
    3.times do
      account.products.create(name: "test#{count}", description: "test_description#{count}")
      count += 1
    end
  end

  def get_all_custom_fields
    @account = Account.current || Account.first.make_current
    %w[checkbox date text paragraph number decimal].each do |dom|
      create_custom_field("cf_#{dom}", dom)
    end
    @account = nil
  end

  def get_a_dropdown_custom_field
    @account = Account.current || Account.first.make_current
    create_custom_field_dropdown
    @account = nil
  end

  def get_a_nested_custom_field
    @account = Account.current || Account.first.make_current
    create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
    @account = nil
  end

  def valid_dispatchr_hash(product_id)
    hash = {
        name: "Sample Dispatch'r 77 rule", position: 1, active: false,
        events: [{ field_name: "test_custom_dropdown", from: "Get Smart", to: "Pursuit of Happiness" },
                 {field_name: "test_custom_country", from: "Australia", to: "USA",
                  from_nested_field: { level2: { field_name: "test_custom_state", value: "New South Wales" },
                                       level3: { field_name: "test_custom_city", value: "Sydney" }},
                  to_nested_field: { level2: { field_name: "test_custom_state", value: "California"},
                                     level3: { field_name: "test_custom_city", value: "Burlingame" }}}],
        conditions: {
            condition_set_1: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: ["Refund"] }]},
            operator: "any",
            condition_set_2: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: ["Question"] },

                                        { field_name: "subject_or_description", operator: "contains", value: ["billing"] }]}},
        actions: [
            { field_name: "test_custom_dropdown", value: "Get Smart"}, { field_name: "status", value: 4 },
            { field_name: "product_id", value: product_id },
            { field_name: "add_tag", value: "test1" }, { field_name: "group_id", value: 3 }, { field_name: "test_custom_dropdown", value: "Get Smart"},
            { field_name: "test_custom_country", value: "USA",
              nested_fields: { level2: { field_name: "test_custom_state", value: "Texas" }, level3: { field_name: "test_custom_city", value: "Dallas" }}}]}
    hash
  end

  def invalid_dispatchr_hash
    hash = {
        name: "Sample Dispatch'r 77 rule", position: 5766, active: false,
        performer: { type: 1, members: [578789, 9878796]},
        events: [{ field_name: "cf_age_group", from: "&gt; 5 &amp; &lt; 10", to: "&gt; 5 &amp; &lt; 10",
                   from_nested_field: { level2: { field_name: "cf_gender", value: "Male" },
                                        level3: { field_name: "cf_name", value: "James" }},
                   to_nested_field: { level2: { field_name: "cf_gender", value: "Male"},
                                      level3: { field_name: "cf_name", value: "Don" }}}],
        conditions: {
            condition_set_1: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Refund" }]},
            operator: "any",
            condition_set_2: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Question" },
                                        { field_name: "subject_or_description", operator: "contains", value: "billing" }]}},
        actions: [{ field_name: "status", value: 4678 }, { field_name: "product_id", value: 4576} , { field_name: "add_tag", value: "test1bhj" },
                  { field_name: "test_custom_dropdown", value: "Get Smart guy"}, { field_name: "group_id", value: 497 },
                  { field_name: "cf_age_group", value: "&gt; 5 &amp; &lt; 10",
                    nested_fields: { level2: { field_name: "cf_gender", value: "Male" }, level3: { field_name: "cf_name", value: "Kohli" }}}]}
    hash
  end

  def valid_observer_hash(product_id)
    hash = {
        name: "Sample Dispatch'r 77 rule", position: 1, active: false,
        performer: { type: 1, members: [1] },
        events: [{ field_name: "test_custom_dropdown", from: "Get Smart", to: "Pursuit of Happiness" },
                 { field_name: "test_custom_country", from: "Australia", to: "USA",
                   from_nested_field: { level2: { field_name: "test_custom_state", value: "New South Wales" },
                                        level3: { field_name: "test_custom_city", value: "Sydney" }},
                   to_nested_field: { level2: { field_name: "test_custom_state", value: "California"},
                                      level3: { field_name: "test_custom_city", value: "Burlingame" }}}],
        conditions: {
            condition_set_1: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: ["Refund"] }]},
            operator: "any",
            condition_set_2: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: ["Question"] },
                                        { field_name: "subject_or_description", operator: "contains", value: "billing" }]}},
        actions: [{ field_name: "status", value: 4 }, { field_name: "product_id", value: product_id }, { field_name: "add_tag", value: "test1" },
                  { field_name: "group_id", value: 3 }, { field_name: "test_custom_dropdown", value: "Get Smart"},
                  { field_name: "cf_decimal", value: 3.55 }, { field_name: "cf_number", value: 8 },{ field_name: "cf_paragraph", value: "etryuvbij" }, { field_name: "cf_text", value: "cgvhbjk" },
                  { field_name: "cf_date", value: "22-10-2019" }, { field_name: "cf_checkbox", value: "not_selected" },
                  { field_name: "test_custom_country", value: "USA",
                    nested_fields: { level2: { field_name: "test_custom_state", value: "Texas" }, level3: { field_name: "test_custom_city", value: "Dallas" }}}]}
    hash
  end

  def invalid_observer_hash
    hash = {
        name: "Sample Dispatch'r 77 rule", position: 5766, active: false,
        performer: { type: 1, members: [578789, 9878796]},
        events: [
            { field_name: "cf_age_group", from: "&gt; 5 &amp; &lt; 10", to: "&gt; 5 &amp; &lt; 10",
              from_nested_field: { level2: { field_name: "cf_gender", value: "Male" },
                                   level3: { field_name: "cf_name", value: "James" }},
              to_nested_field: { level2: { field_name: "cf_gender", value: "Male"},
                                 level3: { field_name: "cf_name", value: "Don" }}}],
        conditions: {
            condition_set_1: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Refund" }]},
            operator: "any",
            condition_set_2: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Question" },

                                        { field_name: "subject_or_description", operator: "contains", value: "billing" }]}},
        actions: [
            { field_name: "group_id", value: 497 }, { field_name: "status", value: 6784 }, { field_name: "product_id", value: 4678 },
            { field_name: "add_tag", value: "test1t8" }, { field_name: "group_id", value: 389 }, { field_name: "test_custom_dropdown", value: "Get Smart people"},
            { field_name: "cf_decimal", value: "fcgv" }, { field_name: "cf_number", value: "tfuygih" },{ field_name: "cf_paragraph", value: [1, 2] }, { field_name: "cf_text", value: "cgvhbjk" },
            { field_name: "cf_date", value: "2018-32-12" }, { field_name: "cf_checkbox", value: "dummy" },
            { field_name: "cf_age_group", value: "&gt; 5 &amp; &lt; 10",
              nested_fields: { level2: { field_name: "cf_gender", value: "Male" }, level3: { field_name: "cf_name", value: "Kohli" }}}]}
    hash
  end

  def valid_observer_array_hash
    hash = {
        name: "Sample Dispatch'r 77 rule", position: 1, active: false,
        performer: { type: 1, members: [1] },
        events: [{ field_name: "test_custom_dropdown", from: "Get Smart", to: "Pursuit of Happiness" },
                 { field_name: "test_custom_country", from: "Australia", to: "USA",
                   from_nested_field: { level2: { field_name: "test_custom_state", value: "New South Wales" },
                                        level3: { field_name: "test_custom_city", value: "Sydney" }},
                   to_nested_field: { level2: { field_name: "test_custom_state", value: "California"},
                                      level3: { field_name: "test_custom_city", value: "Burlingame" }}}],
        conditions: {
            condition_set_1: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: ["Refund"] },
                                        { field_name: "test_custom_country", operator: "is_any_of", value: ["USA", "Australia"]},
                                        { field_name: "test_custom_dropdown", operator: "is_any_of", value: ["Get Smart", "Pursuit of Happiness", "Armaggedon"]}]},
            operator: "any",
            condition_set_2: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Question" },
                                        { field_name: "subject_or_description", operator: "contains", value: "billing" }]}},
        actions: [{ field_name: "status", value: 4 }, { field_name: "add_tag", value: "test1" },
                  { field_name: "group_id", value: 3 }, { field_name: "test_custom_dropdown", value: "Get Smart"},
                  { field_name: "cf_decimal", value: 3.55 }, { field_name: "cf_number", value: 8 },{ field_name: "cf_paragraph", value: "etryuvbij" }, { field_name: "cf_text", value: "cgvhbjk" },
                  { field_name: "cf_date", value: "12-10-2010" }, { field_name: "cf_checkbox", value: "not_selected" }]}
    hash
  end

  def invalid_observer_array_hash
    hash = {
        name: "Sample Dispatch'r 77 rule", position: 1, active: false,
        performer: { type: 1, members: [1] },
        events: [{ field_name: "test_custom_dropdown", from: "Get Smart", to: "Pursuit of Happiness" },
                 { field_name: "test_custom_country", from: "Australia", to: "USA",
                   from_nested_field: { level2: { field_name: "test_custom_state", value: "New South Wales" },
                                        level3: { field_name: "test_custom_city", value: "Sydney" }},
                   to_nested_field: { level2: { field_name: "test_custom_state", value: "California"},
                                      level3: { field_name: "test_custom_city", value: "Burlingame" }}}],
        conditions: {
            condition_set_1: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Refund" },
                                        { field_name: "test_custom_country", operator: "is", value: ["USA", "Australia"],
                                          nested_fields: { level2: { field_name: "test_custom_state", operator: "is", value: ["New South Wales"] },
                                                           level3: { field_name: "test_custom_city", operator: "is", value: "Sydney" }}},
                                        { field_name: "test_custom_dropdown", operator: "is", value: ["Get Smart", "Pursuit of Happiness", "Armaggedon"]}]},
            operator: "any",
            condition_set_2: { match_type: "all",
                               ticket: [{ field_name: "ticket_type", operator: "in", value: "Question" },
                                        { field_name: "subject_or_description", operator: "contains", value: "billing" }]}},
        actions: [{ field_name: "status", value: 4 }, { field_name: "add_tag", value: "test1" },
                  { field_name: "group_id", value: 3 }, { field_name: "test_custom_dropdown", value: "Get Smart"},
                  { field_name: "cf_decimal", value: 3.55 }, { field_name: "cf_number", value: 8 },{ field_name: "cf_paragraph", value: "etryuvbij" },
                  { field_name: "cf_text", value: "cgvhbjk" }, { field_name: "cf_date", value: "2018-12-12" },
                  { field_name: "cf_checkbox", value: "not_selected" }, { field_name: "test_custom_country", value: "Australia"}]}
    hash
  end

  # def invalid_nested_field_keys
  #   hash = {
  #       name: "Sample Dispatch'r 77 rule", position: 1, active: false,
  #       performer: { type: 1, members: [1] },
  #       events: [{ field_name: "test_custom_dropdown", from: "Get Smart", to: "Pursuit of Happiness" },
  #                { field_name: "test_custom_country", from: "Australia", to: "USA",
  #                  from_nested_field: { level22: { field_name: "test_custom_state", value: "New South Wales" },
  #                                       level3: { field_name: "test_custom_city", value: "Sydney" }},
  #                  to_nested: { level2: { field_name: "test_custom_state", value: "California"},
  #                                     level3: { field_name: "test_custom_city", value: "Burlingame" }}}],
  #       conditions: {
  #           condition_set_1: { match_type: "all",
  #                              ticket: [{ field_name: "ticket_type", operator: "in", value: "Refund" },
  #                                       { field_name: "test_custom_country", operator: "is_any_of", value: ["USA", "Australia"],
  #                                         nested_fields: [{ field_name: "test_custom_state", from: "New South Wales" },
  #                                                         { field_name: "test_custom_city", xx: "Sydney" }]},
  #                                       { field_name: "test_custom_dropdown", operator: "is_any_of", value: ["Get Smart", "Pursuit of Happiness", "Armaggedon"]}]},
  #           operator: "any",
  #           condition_set_2: { match_type: "all",
  #                              ticket: [{ field_name: "ticket_type", operator: "in", value: "Question" },
  #                                       { field_name: "subject_or_description", operator: "contains", value: "billing" }]}},
  #       actions: [{ field_name: "status", value: 4 }, { field_name: "add_tag", value: "test1" },
  #                 { field_name: "group_id", value: 3 }, { field_name: "test_custom_dropdown", value: "Get Smart"},
  #                 { field_name: "cf_decimal", value: 3.55 }, { field_name: "cf_number", value: 8 },{ field_name: "cf_paragraph", value: "etryuvbij" }, { field_name: "cf_text", value: "cgvhbjk" },
  #                 { field_name: "cf_date", value: "2018-12-12" }, { field_name: "cf_checkbox", rr: "not_selected" },
  #                 { field_name: "test_custom_country", cc: ["Australia"]}]}
  #   hash
  # end
end