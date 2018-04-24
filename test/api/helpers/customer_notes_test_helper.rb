module CustomerNotesTestHelper
  def note_pattern(expected_output, note)
    response_pattern = {
      id: Fixnum,
      title: expected_output[:title] || note.title,
      created_by: note.created_by_name,
      last_updated_by: note.last_updated_by_name,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      attachments: Array
    }
    response_pattern[:body] = expected_output[:body] || note.body unless note.s3_key?
    response_pattern[:s3_url] = note.s3_url if note.s3_key?
    response_pattern
  end

  def contact_note_pattern(expected_output, note)
    note_pattern(expected_output, note).merge(
      contact_id: expected_output[:user_id] || note.user_id
    )
  end

  def company_note_pattern(expected_output, note)
    note_pattern(expected_output, note).merge(
      company_id: expected_output[:company_id] || note.company_id,
      category_id: expected_output[:category_id] || note.category_id
    )
  end

  def create_contact_note(params = {})
    contact = @account.all_contacts.find_by_id(params[:user_id])
    test_note = contact.contact_notes.new(params.except(:user_id))
    if params[:attachments]
      test_note.attachments.build(content: params[:attachments][:resource],
                                  description: params[:attachments][:description],
                                  account_id: test_note.account_id)
    end
    test_note.build_note_body(body: params[:body])
    test_note.save
    test_note
  end

  def _create_contact_note(contact, agent)
    create_contact_note(
      title: Faker::Lorem.characters(30),
      user_id: contact.id,
      created_by: agent.id,
      body: Faker::Lorem.paragraph
    )
  end

  def create_company_note(params = {})
    company = @account.companies.find_by_id(params[:company_id])
    test_note = company.notes.new(params.except(:company_id))
    if params[:attachments]
      test_note.attachments.build(content: params[:attachments][:resource],
                                  description: params[:attachments][:description],
                                  account_id: test_note.account_id)
    end
    test_note.build_note_body(body: params[:body])
    test_note.save
    test_note
  end

  def _create_company_note(company, agent)
    create_company_note(
      title: Faker::Lorem.characters(30),
      company_id: company.id,
      created_by: agent.id,
      body: Faker::Lorem.paragraph
    )
  end
end
