require_relative '../../test_helper'
class Contacts::MergeControllerTest < ActionController::TestCase
  include UsersTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.add_feature(:multiple_user_companies)
    @account.reload
    create_sample_companies
    @@before_all_run = true
  end

  def wrap_cname(params)
    { merge: params }
  end

  def create_sample_companies
    @@other_company_ids = []
    (User::MAX_USER_COMPANIES).times do
      company = create_company
      @@other_company_ids << company.id
    end
  end

  def test_merge_with_no_params
    post :merge, construct_params({})
    assert_response 400
    match_json([bad_request_error_pattern(:primary_contact_id, :missing_field),
                bad_request_error_pattern(:secondary_contact_ids, :missing_field)])
  end

  def test_merge_with_non_existing_primary_contact
    post :merge, construct_params(
      primary_contact_id: (User.last.try(:id) || 0) + 10,
      secondary_contact_ids: [1, 2],
      contact: {
        phone: Faker::Lorem.characters(9),
        mobile: Faker::Lorem.characters(9),
        twitter_id: Faker::Lorem.characters(9),
        fb_profile_id: Faker::Lorem.characters(9),
        other_emails: ["s@g.com"],
        company_ids: [1, 2]
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern(:primary_contact_id, :invalid_primary_contact_id)])
  end

  def test_merge_with_merged_primary_contact
    primary_contact = add_new_user(@account)
    primary_contact.parent_id = 999
    primary_contact.save
    post :merge, construct_params(
      primary_contact_id: primary_contact.id,
      secondary_contact_ids: [1, 2],
      contact: {
        phone: Faker::Lorem.characters(9),
        mobile: Faker::Lorem.characters(9),
        twitter_id: Faker::Lorem.characters(9),
        fb_profile_id: Faker::Lorem.characters(9),
        other_emails: ["s@g.com"],
        company_ids: [1, 2]
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern(:primary_contact_id, :merged_primary_contact_id)])
  end

  def test_merge_with_deleted_primary_contact
    primary_contact = add_new_user(@account, deleted: true)
    post :merge, construct_params(
      primary_contact_id: primary_contact.id,
      secondary_contact_ids: [1, 2],
      contact: {
        phone: Faker::Lorem.characters(9),
        mobile: Faker::Lorem.characters(9),
        twitter_id: Faker::Lorem.characters(9),
        fb_profile_id: Faker::Lorem.characters(9),
        other_emails: ["s@g.com"],
        company_ids: [1, 2]
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern(:primary_contact_id, :deleted_primary_contact_id)])
  end


  def test_merge_with_invalid_secondary_contact_ids
    primary_contact = add_new_user(@account)
    invalid_ids = [primary_contact.id + 10, primary_contact.id + 20]
    post :merge, construct_params(
      primary_contact_id: primary_contact.id,
      secondary_contact_ids: invalid_ids,
      contact: {
        phone: Faker::Lorem.characters(9),
        mobile: Faker::Lorem.characters(9),
        twitter_id: Faker::Lorem.characters(9),
        fb_profile_id: Faker::Lorem.characters(9),
        other_emails: ["s@g.com"],
        company_ids: [1, 2]
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern(:secondary_contact_ids, :invalid_list, list: invalid_ids.join(', '))])
  end

  def test_merge_with_deleted_secondary_contact_ids
    secondary_contact_ids = []
    other_emails = []
    primary_contact = add_new_user(@account)
    target_user = add_new_user(@account, deleted: true)
    secondary_contact_ids << target_user.id
    other_emails << target_user.email
    post :merge, construct_params(
      primary_contact_id: primary_contact.id,
      secondary_contact_ids: secondary_contact_ids,
      contact: {
        phone: primary_contact.phone,
        email: primary_contact.email,
        mobile: primary_contact.mobile,
        other_emails: other_emails,
        company_ids: [1,2]
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern(:secondary_contact_ids, :deleted_list, list: secondary_contact_ids.join(', '))])
  end

  def test_merge_with_merged_secondary_contact_ids
    secondary_contact_ids = []
    other_emails = []
    primary_contact = add_new_user(@account)
    target_user = add_new_user(@account, deleted: true)
    secondary_contact_ids << target_user.id
    other_emails << target_user.email
    target_user.parent_id = 999
    target_user.save
    post :merge, construct_params(
      primary_contact_id: primary_contact.id,
      secondary_contact_ids: secondary_contact_ids,
      contact: {
        email: primary_contact.email,
        phone: primary_contact.phone,
        mobile: primary_contact.mobile,
        other_emails: other_emails,
        company_ids: [1, 2]
      }
    )
    assert_response 400
    match_json([bad_request_error_pattern(:secondary_contact_ids, :merged_list, list: secondary_contact_ids.join(', '))])
  end

  def test_merge_validation_failures
    primary_contact = add_new_user(@account)
    secondary_contact_ids = []
    target_user = add_user_with_multiple_emails(@account, User::MAX_USER_EMAILS - 1)
    secondary_contact_ids << target_user.id
    other_emails = target_user.emails
    params_hash = { primary_contact_id: primary_contact.id, secondary_contact_ids: secondary_contact_ids, contact: { other_emails: other_emails, phone: primary_contact.phone } }
    post :merge, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('other_emails', :too_long, element_type: :values, max_count: ContactConstants::MAX_OTHER_EMAILS_COUNT, current_count: other_emails.size)])
  end

  def test_merge_success
    primary_contact = add_new_user(@account, customer_id: create_company.id)
    secondary_contact_ids = []
    other_emails = []
    company_ids = []
    sample_company_ids = @@other_company_ids.first(4)
    rand(2..4).times do |ind|
      target_user = add_new_user(@account, customer_id: sample_company_ids[ind])
      secondary_contact_ids << target_user.id
      other_emails << target_user.email
      company_ids << sample_company_ids[ind]
    end
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: secondary_contact_ids,
                    contact: { email: primary_contact.email,
                               other_emails: other_emails,
                               company_ids: company_ids,
                               phone: primary_contact.phone,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    assert_response 204
    primary_contact.reload
    assert_equal (other_emails.size + 1), primary_contact.user_emails.count
    assert_equal company_ids.size, primary_contact.user_companies.count
    Account.current.all_contacts.where(id: secondary_contact_ids).each { |x| assert x.deleted }
  end

  def test_merge_success_without_primary_email
    primary_contact = add_new_user_without_email(@account, customer_id: create_company.id)
    secondary_contact_ids = []
    other_emails = []
    company_ids = []
    sample_company_ids = @@other_company_ids.first(4)
    rand(2..4).times do |ind|
      target_user = add_new_user(@account, customer_id: sample_company_ids[ind])
      secondary_contact_ids << target_user.id
      other_emails << target_user.email
      company_ids << sample_company_ids[ind]
    end
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: secondary_contact_ids,
                    contact: { phone: primary_contact.phone,
                               other_emails: other_emails,
                               company_ids: company_ids,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    assert_response 204
    primary_contact.reload
    assert_equal (other_emails.size), primary_contact.user_emails.count
    assert_equal company_ids.size, primary_contact.user_companies.count
    Account.current.all_contacts.where(id: secondary_contact_ids).each { |x| assert x.deleted }
  end

  def test_merge_success_with_required_custom_fields
    primary_contact = add_new_user(@account, customer_id: create_company.id)
    cf = create_contact_field(cf_params(type: 'text', field_type: 'custom_text', label: 'another_code', editable_in_signup: 'true', required_for_agent: 'true'))
    secondary_contact_ids = []
    other_emails = []
    company_ids = []
    sample_company_ids = @@other_company_ids.first(4)
    rand(2..4).times do |ind|
      company = create_company
      target_user = add_new_user(@account, customer_id: sample_company_ids[ind])
      secondary_contact_ids << target_user.id
      other_emails << target_user.email
      company_ids << sample_company_ids[ind]
    end
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: secondary_contact_ids,
                    contact: { email: primary_contact.email,
                               other_emails: other_emails,
                               company_ids: company_ids,
                               phone: primary_contact.phone,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    assert_response 204
    primary_contact.reload
    assert_equal (other_emails.size + 1), primary_contact.user_emails.count
    assert_equal company_ids.size, primary_contact.user_companies.count
    Account.current.all_contacts.where(id: secondary_contact_ids).each { |x| assert x.deleted }
  ensure
    cf.update_attribute(:required_for_agent, false)
  end

  def test_unassociated_value_validation_failure
    primary_contact = add_new_user(@account)
    target_user = add_new_user(@account)
    secondary_contact_id = target_user.id
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact_id],
                    contact: { company_ids: [10000],
                               phone: primary_contact.phone + '100',
                               email: 'test'+primary_contact.email,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :unassociated_values, invalid_values: [10000]),
                bad_request_error_pattern('phone', :unassociated_values, invalid_values: [primary_contact.phone + '100']),
                bad_request_error_pattern('other_emails', :unassociated_values, invalid_values: ['test'+primary_contact.email])])
  end

  def test_conflict_validation_failure
    @account.add_feature(:unique_contact_identifier)
    primary_contact = add_new_user(@account, unique_external_id: Faker::Lorem.characters(9))
    secondary_contact_ids = []
    secondary_contact = add_user_with_multiple_emails(@account, User::MAX_USER_EMAILS - 1, unique_external_id: Faker::Lorem.characters(9))
    secondary_contact_ids << secondary_contact.id
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: secondary_contact_ids,
                    contact: { phone: primary_contact.phone,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    unique_external_id_values = ([primary_contact.unique_external_id] + [secondary_contact.unique_external_id]).join(', ')
    other_emails_values = ([primary_contact.emails] + [secondary_contact.emails]).join(', ')
    assert_response 400
    match_json([bad_request_error_pattern('unique_external_id', :fill_a_value, values: unique_external_id_values),
                bad_request_error_pattern('other_emails', :fill_values_upto_max_limit, values: other_emails_values, max_limit: ContactConstants::MAX_OTHER_EMAILS_COUNT)])
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_conflict_validation_failure_with_multiple_companies
    primary_contact_company = create_company
    primary_contact = add_new_contractor(@account, { company_ids: [primary_contact_company.id] })
    other_company_ids = @@other_company_ids
    secondary_contact = add_new_contractor(@account, { company_ids: other_company_ids })
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact.id],
                    contact: { phone: primary_contact.phone,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    company_values = (primary_contact.company_ids + secondary_contact.company_ids).join(', ')
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :fill_values_upto_max_limit, values: company_values, max_limit: User::MAX_USER_COMPANIES)])
  end

  def test_conflict_validation_for_company_ids
    @account.revoke_feature(:multiple_user_companies)
    primary_contact_company = create_company
    primary_contact = add_new_user(@account, customer_id: primary_contact_company.id)
    secondary_contact_company = create_company
    secondary_contact  = add_new_user(@account, { customer_id: secondary_contact_company.id })
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact.id],
                    contact: { phone: primary_contact.phone,
                               mobile: primary_contact.mobile } }
    post :merge, construct_params(params_hash)
    company_ids = ([primary_contact.company_id] + [secondary_contact.company_id]).join(', ')
    assert_response 400
    match_json([bad_request_error_pattern('company_ids', :fill_a_value, values: company_ids)])
    @account.add_feature(:multiple_user_companies)
    @account.reload
  end

  def test_mandatory_value_validation_failure
    primary_contact = add_new_user(@account)
    company = create_company
    secondary_contact  = add_new_user(@account, { customer_id: company.id })
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact.id],
                    contact: {
                      email: nil,
                      other_emails: [],
                      phone: '',
                      mobile: nil
                    } }
    post :merge, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('contact', :fill_a_mandatory_field, field_names: (ContactConstants::MERGE_MANDATORY_FIELDS - [:external_id]).join(', '))])
  end

  def test_merge_with_invalid_params
    primary_contact = add_new_user(@account)
    company = create_company
    secondary_contact  = add_new_user(@account, { customer_id: company.id })
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact.id],
                    contact: {
                      email: nil,
                      other_emails: [],
                      phone: '',
                      mobile: nil,
                      test_field: nil
                    } }
    post :merge, construct_params(params_hash)
    assert_response 400
    match_json([bad_request_error_pattern('test_field', :invalid_field)])
  end

  def test_merge_success_with_missing_fields
    primary_contact = add_new_user_without_email(@account)
    other_emails = []
    company = create_company
    @account.add_feature(:unique_contact_identifier)
    secondary_contact  = add_new_user(@account, { customer_id: company.id, unique_external_id: Faker::Lorem.characters(9) })
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact.id],
                    contact: {
                      phone: secondary_contact.phone,
                      mobile: secondary_contact.mobile
                    } }
    post :merge, construct_params(params_hash)
    assert_response 204
    primary_contact.reload
    assert_equal secondary_contact.company_ids, primary_contact.company_ids
    assert_equal secondary_contact.email, primary_contact.email
    assert_equal secondary_contact.unique_external_id, primary_contact.unique_external_id
    @account.revoke_feature(:unique_contact_identifier)
  end

  def test_merge_success_with_missing_email_fields
    primary_contact = add_new_user(@account)
    email = primary_contact.email
    secondary_contact = add_new_user(@account)
    params_hash = { primary_contact_id: primary_contact.id,
                    secondary_contact_ids: [secondary_contact.id],
                    contact: {
                      phone: secondary_contact.phone,
                      mobile: secondary_contact.mobile
                    } }
    post :merge, construct_params(params_hash)
    assert_response 204
    primary_contact.reload
    emails = [email, [secondary_contact].map(&:email)].flatten
    assert_equal email, primary_contact.email
    assert_equal primary_contact.emails.sort, emails.sort
  end
end
