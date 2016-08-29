require_relative '../../test_helper'
module ApiIntegrations
  class CtiControllerTest < ActionController::TestCase
    include NoteHelper
    include TicketHelper
    def wrap_cname(params)
      { api_cti: params }
    end

    def setup
      super
      Integrations::InstalledApplication.any_instance.stubs(:marketplace_enabled?).returns(false)
      @account.add_features([:cti])
      application = Integrations::Application.find_by_name("cti")
      @installed_app = @account.installed_applications.build(:application => application)
      @installed_app.set_configs("softfone_enabled" => "0", "call_note_private" => "1", "click_to_dial" => "0")
      @installed_app.save!
    end

    def teardown
      super
      @account.installed_applications.destroy_all
      @account.remove_feature(:cti)
      Integrations::InstalledApplication.unstub(:marketplace_enabled?)
    end

    def test_create_with_feature_disabled
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      @account.class.any_instance.stubs(:features?).returns(false)
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)

      assert_response 403
    end

    def test_req_id_and_resp_id_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)
      assert_response 200
      cti_call = @account.cti_calls.where(:call_sid => call_sid).first
      assert_equal(cti_call.requester, requester)
      assert_equal(cti_call.responder, responder)
      assert_equal(cti_call.call_sid, call_sid)
      assert_equal(cti_call.options[:call_url], call_url)
      assert_equal(cti_call.options[:call_info], call_info)
      cti_call.destroy
    end

    def test_existing_requester_phone_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user_without_email(@account, :phone => "9145462663")
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_phone => requester.phone,
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)
      assert_response 200
      cti_call = @account.cti_calls.where(:call_sid => call_sid).first
      assert_equal(cti_call.requester, requester)
      requester.destroy
      responder.destroy
      cti_call.destroy
    end

    def test_new_requester_phone_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_phone => "978784144444",
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                     }, false)
      assert_response 200
      cti_call = @account.cti_calls.where(:call_sid => call_sid).first
      assert_not_nil(cti_call.requester.id)
      cti_call.requester.destroy
      cti_call.destroy
    end

    def test_invalid_req_id_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => 9876578,
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "requester_id",
            message: "There is no contact matching the given requester_id",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)
    end

    def test_with_no_requester_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)
      assert_response 400
            expected = {
        description: "Validation failed",
        errors: [
          {
            field: "requester_id",
            message: "Please fill at least 1 of requester_id, requester_phone fields",
            code: "missing_field"
          }
        ]
      }
      match_json(expected)

    end

    def test_invalid_resp_id_create
      requester = add_new_user(@account)
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_id => 982958725,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "responder_id",
            message: "There is no agent matching the given responder_id",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)

    end

    def test_with_no_responder_create
      requester = add_new_user(@account)
      call_sid = "125437"
      call_url = "http://abc.abc.com/125437"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "responder_id",
            message: "Please fill at least 1 of responder_id, responder_phone fields",
            code: "missing_field"
          }
        ]
      }
      match_json(expected)

    end

    def test_valid_responder_phone_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      cti_phone = @account.cti_phones.create(:phone => "9940999214", :agent_id => responder.id)
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_phone => cti_phone.phone,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                     }, false)
      assert_response 200
      cti_call = @account.cti_calls.where(:call_sid => call_sid).first
      assert_equal(cti_call.responder, responder)
      cti_phone.destroy
      cti_call.destroy
    end

    def test_valid_responder_phone_no_agent_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      cti_phone = @account.cti_phones.create(:phone => "9940999216")
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_phone => cti_phone.phone,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "responder_phone",
            message: "There is no agent matching the given responder_phone",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)

      responder.destroy
      cti_phone.destroy
    end

    def test_invalid_responder_phone_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_phone => "972359285672",
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "responder_phone",
            message: "There is no agent matching the given responder_phone",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)
      responder.destroy
      requester.destroy
    end

    def test_invalid_ticket_id_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      cti_phone = @account.cti_phones.create(:phone => "9940999214", :agent_id => responder.id)
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_phone => cti_phone.phone,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                       :ticket_id => 1253515423
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "ticket_id",
            message: "There is no ticket matching the given ticket_id",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)
      cti_phone.destroy
      responder.destroy
      requester.destroy
    end

    def test_valid_ticket_id_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      cti_phone = @account.cti_phones.create(:phone => "9940999214", :agent_id => responder.id)
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      ticket = create_ticket(:requester_id => requester.id)
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_phone => cti_phone.phone,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                       :ticket_id => ticket.display_id
                                     }, false)
      assert_response 200
      cti_call = @account.cti_calls.where(:call_sid => call_sid).first
      assert_equal(cti_call.options[:ticket_id], ticket.display_id)
      cti_phone.destroy
      cti_call.destroy
    end

    def test_invalid_call_error_msgs_create
      post :create, construct_params({
                                       :requester_id => 32532525,
                                       :responder_id => 235223,
                                       :call_reference_id => "325125235",
                                       :ticket_id => 3525161642
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "ticket_id",
            message: "There is no ticket matching the given ticket_id",
            code: "invalid_value"
          },
          {
            field: "requester_id",
            message: "There is no contact matching the given requester_id",
            code: "invalid_value"
          },
          {
            field: "responder_id",
            message: "There is no agent matching the given responder_id",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)
    end

    def test_invalid_call_phone_error_msgs_create
      post :create, construct_params({
                                       :requester_id => 32532525,
                                       :responder_phone => "3252627278282",
                                       :call_reference_id => "325125235",
                                       :ticket_id => 3525161642
                                     }, false)
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "ticket_id",
            message: "There is no ticket matching the given ticket_id",
            code: "invalid_value"
          },
          {
            field: "responder_phone",
            message: "There is no agent matching the given responder_phone",
            code: "invalid_value"
          },
          {
            field: "requester_id",
            message: "There is no contact matching the given requester_id",
            code: "invalid_value"
          }
        ]
      }
      match_json(expected)
    end

    def test_new_ticket_option_create
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user(@account)
      call_sid = "125438"
      call_url = "http://abc.abc.com/125438"
      call_info = {"custom_data" => "blah"}
      post :create, construct_params({
                                       :requester_id => requester.id,
                                       :responder_id => responder.id,
                                       :call_reference_id => call_sid,
                                       :call_url => call_url,
                                       :call_info => call_info,
                                       :new_ticket => true
                                     }, false)
      assert_response 200
      cti_call = @account.cti_calls.where(:call_sid => call_sid).first
      assert_instance_of(Helpdesk::Ticket, cti_call.recordable)
      cti_call.destroy
      responder.destroy
      requester.destroy
    end

    def test_index_with_feature_disabled
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user_without_email(@account, :phone => "9145462663")
      @account.class.any_instance.stubs(:features?).returns(false)
      cti_call = @account.cti_calls.create({
                                             :requester_id => requester.id,
                                             :responder_id => responder.id,
                                             :call_sid => "634623424536"
                                           })
      get :index, controller_params(call_reference_id: cti_call.call_sid)
      assert_response 403
      expected = {
        code: "require_feature",
        message: "The Cti feature(s) is/are not supported in your plan. Please upgrade your account to use it."
      }
      match_json(expected)
      cti_call.destroy
      responder.destroy
      requester.destroy
      @account.class.any_instance.unstub(:features?)
    end

    def test_without_call_reference_id_index
      get :index, controller_params
      assert_response 400
      expected = {
        description: "Validation failed",
        errors: [
          {
            field: "call_reference_id",
            message: "It should be a/an String",
            code: "missing_field"
          }
        ]
      }
      match_json(expected)
    end

    def test_with_ticket_index
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user_without_email(@account, :phone => "9145462663")
      ticket = create_ticket(:requester_id => requester.id)
      cti_call = @account.cti_calls.create({
                                             :requester_id => requester.id,
                                             :responder_id => responder.id,
                                             :call_sid => "634623424",
                                             :recordable => ticket,
                                           })
      expected = [
        {
          "requester_id" => requester.id,
          "responder_id" => responder.id,
          "ticket_id" => ticket.display_id,
          "note_id" => nil
        }
      ]
      get :index, controller_params(call_reference_id: cti_call.call_sid)
      assert_response 200
      assert_equal(expected, JSON.parse(@response.body))
      cti_call.destroy
      responder.destroy
      requester.destroy
      ticket.destroy
    end

    def test_with_note_index
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user_without_email(@account, :phone => "9145462663")
      ticket = create_ticket(:requester_id => requester.id)
      note = create_note(:ticket_id => ticket.id, :user_id => responder.id, :source => 9)
      cti_call = @account.cti_calls.create({
                                             :requester_id => requester.id,
                                             :responder_id => responder.id,
                                             :call_sid => "6346234245",
                                             :recordable => note,
                                           })
      expected = [
        {
          "requester_id" => requester.id,
          "responder_id" => responder.id,
          "ticket_id" => ticket.display_id,
          "note_id" => note.id
        }
      ]
      get :index, controller_params(call_reference_id: cti_call.call_sid)
      assert_response 200
      assert_equal(expected, JSON.parse(@response.body))
      responder.destroy
      requester.destroy
      ticket.destroy
      cti_call.destroy
    end

    def test_with_multiple_match_index
      responder = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      responder1 = add_test_agent(@account, role: Role.find_by_name('Agent').id)
      requester = add_new_user_without_email(@account, :phone => "9145462663")
      ticket = create_ticket(:requester_id => requester.id)
      note = create_note(:ticket_id => ticket.id, :user_id => responder.id, :source => 9)
      cti_call = @account.cti_calls.create({
                                             :requester_id => requester.id,
                                             :responder_id => responder.id,
                                             :call_sid => "634623424",
                                             :recordable => note,
                                           })
      cti_call1 = @account.cti_calls.create({
                                              :requester_id => requester.id,
                                              :responder_id => responder1.id,
                                              :call_sid => "634623424"
                                            })
      expected = [
        {
          "requester_id" => requester.id,
          "responder_id" => responder.id,
          "ticket_id" => ticket.display_id,
          "note_id" => note.id
        },
        {
          "requester_id" => requester.id,
          "responder_id" => responder1.id,
          "ticket_id" => nil,
          "note_id" => nil
        }
      ]
      get :index, controller_params(call_reference_id: cti_call.call_sid)
      assert_response 200
      assert_equal(expected, JSON.parse(@response.body))
      responder.destroy
      requester.destroy
      ticket.destroy
      cti_call.destroy
      cti_call1.destroy
    end

  end
end
