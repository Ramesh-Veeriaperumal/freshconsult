module Admin::TicketFieldHelper

  DROPDOWN_CHOICES_TICKET_TYPE = %w[Question Problem Incident].freeze

  def launch_ticket_field_revamp
    begin
      @account.launch :ticket_field_revamp
      yield
    rescue => e
      p e
    ensure
      @account.rollback :ticket_field_revamp
    end
  end


  def default_field_deletion_error_message?(tf)
    {
      'description' => 'Validation failed',
      'errors' => [
        {
          'field' => tf.name,
          'message' => "Default field '#{tf.name}' can't be deleted",
          'code' => 'invalid_value'
        }
      ]
    }
  end

  def create_ticket_fields_of_all_types
    name = 'checkbox' + Faker::Lorem.characters(rand(10..20))
    create_custom_field(name, :checkbox, rand(0..1) == 1)
    name = 'date' + Faker::Lorem.characters(rand(10..20))
    create_custom_field(name, :date, rand(0..1) == 1)
    name = "decimal_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field(name, :decimal, rand(0..1) == 1)
    name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dropdown(name, Faker::Lorem.words(6))
    name = 'number' + Faker::Lorem.characters(rand(10..20))
    create_custom_field(name, :number, field_num: '01', required: rand(0..1) == 1)
    name = "text_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dn(name, 'text', rand(0..1) == 1)
    name = "paragraph_#{Faker::Lorem.characters(rand(10..20))}"
    create_custom_field_dn(name, 'paragraph', rand(0..1) == 1)
    names = Faker::Lorem.words(3).map { |x| "nested_#{x}" }
    create_dependent_custom_field(names, 2, rand(0..1) == 1)
    name = "dropdown_#{Faker::Lorem.characters(rand(10..20))}"
    tf = create_custom_field_dropdown_with_sections(name, DROPDOWN_CHOICES_TICKET_TYPE)
    create_section_fields(tf.id)
  end
end
