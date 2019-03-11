require_relative '../test_helper'
require 'sidekiq/testing'

class HelpWidgetsControllerTest < ActionController::TestCase
  include HelpWidgetsTestHelper
  include ProductsHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    @account.launch(:help_widget)
  end

  def stub_freshmarketer_client
    ::Freshmarketer::Client.any_instance.stubs(:enable_predictive_support).returns(true)
    ::Freshmarketer::Client.any_instance.stubs(:disable_predictive_support).returns(true)
    ::Freshmarketer::Client.any_instance.stubs(:enable_predictive_integration).returns(true)
    ::Freshmarketer::Client.any_instance.stubs(:disable_predictive_integration).returns(true)
    ::Freshmarketer::Client.any_instance.stubs(:create_experiment).returns(exp_id: 'test', status: true)
    ::Freshmarketer::Client.any_instance.stubs(:fetch_cdn_script).returns(freshmarketer_hash[:cdn_script])
  end

  def unstub_freshmarketer_client
    ::Freshmarketer::Client.any_instance.unstub(:enable_predictive_support)
    ::Freshmarketer::Client.any_instance.unstub(:disable_predictive_support)
    ::Freshmarketer::Client.any_instance.unstub(:enable_predictive_integration)
    ::Freshmarketer::Client.any_instance.unstub(:disable_predictive_integration)
    ::Freshmarketer::Client.any_instance.unstub(:create_experiment)
    ::Freshmarketer::Client.any_instance.unstub(:fetch_cdn_script)
  end

  def test_index
    create_widget
    get :index, controller_params(version: 'v2')
    pattern = []
    Account.current.help_widgets.active.all.each do |help_widget|
      pattern << widget_list_pattern(help_widget)
    end
    assert_response 200
    match_json(pattern)
  end

  def test_index_with_invalid_field
    get :index, controller_params(version: 'v2', test: 'test')
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:test, 'Unexpected/invalid field in request', code: 'invalid_field')))
  end

  def test_show
    help_widget = create_widget
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 200
    match_json(widget_show_pattern(help_widget))
  end

  def test_freshmarketer_info
    AccountAdditionalSettings.any_instance.stubs(:freshmarketer_hash).returns(freshmarketer_hash)
    get :freshmarketer_info, controller_params(version: 'v2')
    assert_response 200
    assert JSON.parse(@response.body)['freshmarketer_name'] == 'harlin-mani.fmstack2.com'
  end

  def test_show_with_invalid_help_widget_id
    get :show, controller_params(version: 'v2', id: 0)
    assert_response 404
  end

  def test_show_without_access
    help_widget = create_widget
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 403
    match_json(request_error_pattern(:access_denied))
    User.any_instance.unstub(:privilege?)
  end

  def test_show_with_invalid_field
    help_widget = create_widget
    get :show, controller_params(version: 'v2', id: help_widget.id, test: 'test')
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:test, 'Unexpected/invalid field in request', code: 'invalid_field')))
  end

  def test_show_without_feature
    help_widget = create_widget
    @account.rollback(:help_widget)
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 404
    @account.launch(:help_widget)
  end

  def test_show_with_incorrect_credentials
    create_widget
    @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
    help_widget = Account.current.help_widgets.active.first
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 401
    @controller.unstub(:api_current_user)
  end

  def test_delete
    help_widget = create_widget
    delete :destroy, controller_params(version: 'v2', id: help_widget.id)
    assert_response 204
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 404
  end

  def test_soft_delete
    help_widget = create_widget
    delete :destroy, controller_params(version: 'v2', id: help_widget.id)
    assert_response 204
    deleted_widget = Account.current.help_widgets.find(help_widget.id)
    refute deleted_widget.active
  end

  def test_soft_delete_with_predictive_support
    link_freshmarketer_account
    stub_freshmarketer_client
    help_widget = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('fresh.com', help_widget.id)
    additional_settings.save
    help_widget.settings[:components][:predictive_support] = true
    help_widget.settings[:predictive_support][:domain_list] = ['test.fresh.com', 'test1.fresh.com']
    help_widget.save
    delete :destroy, controller_params(version: 'v2', id: help_widget.id)
    assert_response 204
    deleted_widget = Account.current.help_widgets.find(help_widget.id)
    refute deleted_widget.active
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == []
    unstub_freshmarketer_client
    unlink_freshmarketer_account
  end

  def test_update_appearance
    widget = create_widget
    request_params = {
      settings: {
        appearance: {
          'theme_color' => '#0f52d5',
          'button_color' => '#16193e'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:appearance][:theme_color] == request_params[:settings][:appearance].fetch('theme_color')
    assert widget.settings[:appearance][:button_color] == request_params[:settings][:appearance].fetch('button_color')
  end

  def test_update_invalid_with_wrong_appearance_format
    widget = create_widget
    request_params = {
      settings: {
        appearance: {
          theme_color: '0f52d5',
          button_color: '16193e'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('settings', 'theme_color', 'It should be in the \'accepted #{attribute}\' format', {code:"invalid_value"})])
  end

  def test_update_contact_form
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        contact_form: {
          form_type: 2
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:contact_form][:form_type] == request_params[:settings][:contact_form][:form_type]
  end

  def test_update_with_invalid_contact_form_type
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        contact_form: {
          form_type: 0
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field(:settings, 'form_type', "It should be one of these values: '1,2'", code: 'invalid_value')])
  end

  def test_update_with_solution_articles
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        components: {
          contact_form: true,
          solution_articles: true
        },
        widget_flow: 1
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    assert widget.settings[:components][:solution_articles] == request_params[:settings][:components][:solution_articles]
    assert widget.settings[:widget_flow] == request_params[:settings][:widget_flow]
  end

  def test_update_with_solution_articles_contact_form_disabled
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        components: {
          contact_form: false,
          solution_articles: true
        },
        widget_flow: 1
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:widget_flow, 'Cannot be set, due to insufficient permissions.', code: 'inaccessible_field')))
  end

  def test_update_with_solution_articles_disabled_contact_form_disabled
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        components: {
          contact_form: false,
          solution_articles: false
        },
        widget_flow: 1
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:widget_flow, 'Cannot be set, due to insufficient permissions.', code: 'inaccessible_field')))
  end

  def test_update_components
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        components: {
          solution_articles: true
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    refute widget.settings[:components] == request_params[:settings][:components]
  end

  def test_update_with_invalid_domain
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.commmmmmmmm']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    match_json(validation_error_pattern(bad_request_error_pattern(:domain_list, 'Sorry, please enter a valid domain.', code: 'invalid_value')))
    assert_response 400
  end

  def test_update_with_predictive_without_domain_list
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: []
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    match_json(validation_error_pattern(bad_request_error_pattern(:domain_list, 'Please specify URLs to track for predictive support.', code: 'invalid_value')))
    assert_response 400
  end

  def test_update_without_predictive_with_domain_list
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: false
        },
        predictive_support: {
          domain_list: ['test.fresh.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    assert widget.settings[:components][:predictive_support] == false
    assert widget.settings[:predictive_support] = predictive_support_hash
    widget.reload
  end

  def test_update_domain_list_to_empty
    widget = create_widget
    widget.settings[:components][:predictive_support] = true
    widget.settings[:predictive_support][:domain_list] = ['test.fresh.com']
    request_params = {
      settings: {
        predictive_support: {
          domain_list: []
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
  end

  def test_update_with_more_than_three_domain
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.com', 'test1.fresh.com', 'test2.fresh.com', 'test3.fresh.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
  end

  def test_update_components_with_predictive_support
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:components][:predictive_support] == true
    assert widget.settings[:freshmarketer][:org_id] == widget_freshmarketer_hash[:org_id]
    assert widget.settings[:freshmarketer][:project_id] == widget_freshmarketer_hash[:project_id]
    assert widget.settings[:freshmarketer][:cdn_script] == widget_freshmarketer_hash[:cdn_script]
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh.com')
    unstub_freshmarketer_client
    unlink_freshmarketer_account
    assert Account.current.account_additional_settings.widget_predictive_support_hash == {}
    widget.reload
    assert widget.settings[:components][:predictive_support] == false
  end

  def test_update_components_with_predictive_support_with_domain_list
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.com', 'fresh.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:predictive_support][:domain_list] == ['test.fresh.com', 'fresh.com']
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh.com')
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_domain_list_with_up_case
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.com', 'TEST.FRESH.COM']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:predictive_support][:domain_list] == ['test.fresh.com']
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh.com')
    refute fm_widget_hash.key?('FRESH.COM')
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_domain_list
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    widget.settings[:components][:predictive_support] = true
    widget.save
    request_params = {
      settings: {
        predictive_support: {
          domain_list: ['test.fresh.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:predictive_support][:domain_list] == ['test.fresh.com']
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh.com')
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_remove_domain_list
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('fresh.com', widget.id)
    additional_settings.save
    widget.settings[:components][:predictive_support] = true
    widget.settings[:predictive_support][:domain_list] = ['test.fresh.com', 'test1.fresh.com']
    widget.save
    request_params = {
      settings: {
        predictive_support: {
          domain_list: ['test.fresh1.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:predictive_support][:domain_list] == ['test.fresh1.com']
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == []
    refute fm_widget_hash.key?('test.fresh.com')
    assert fm_widget_hash['fresh1.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh1.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh1.com')
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_remove_domain_list_with_predictive_enabled
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('fresh.com', widget.id)
    additional_settings.save
    widget.settings[:components][:predictive_support] = false
    widget.settings[:predictive_support][:domain_list] = ['test.fresh.com']
    widget.save
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.com', 'test.fresh1.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:predictive_support][:domain_list] == ['test.fresh.com', 'test.fresh1.com']
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh.com')
    assert fm_widget_hash['fresh1.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh1.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('test.fresh1.com')
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_disable_predictive_support
    widget = create_widget
    link_freshmarketer_account
    stub_freshmarketer_client
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('fresh.com', widget.id)
    additional_settings.save
    widget.settings[:components][:predictive_support] = true
    widget.settings[:predictive_support][:domain_list] = ['test.fresh.com']
    widget.save
    request_params = {
      settings: {
        components: {
          predictive_support: false
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:components][:predictive_support] == false
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['fresh.com'][:exp_id] == 'test'
    assert fm_widget_hash['fresh.com'][:widget_ids] == []
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_with_invalid_components
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        components: {
          script: 'http://wwww.salesforce.com',
          name: 'SalesForce'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:script, 'Invalid settings hash with script', code: 'invalid_value'),
                bad_request_error_pattern(:name, 'Invalid settings hash with name', code: 'invalid_value')])
  end

  def test_update_welcome_message
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        message: 'Hai Dear'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:message] == request_params[:settings][:message]
  end

  def test_update_button_text
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        button_text: 'Submit'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:button_text] == request_params[:settings][:button_text]
  end

  def test_update_name
    widget = create_widget
    request_params = {
      name: 'My_First_Widget'
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    id = JSON.parse(@response.body)['id']
    widget.reload

    match_json(widget_show_pattern(widget))
    assert widget.name == request_params[:name]
  end

  def test_update_invalid_with_invalid_request_parameter
    widget = create_widget
    request_params = {
      name: 'My_First_Widget',
      settings: {
        first: true
      },
      length: 3
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:length, 'Unexpected/invalid field in request', code: 'invalid_field')])
  end

  def test_update_appearance_all
    widget = create_widget
    request_params = {
      name: 'My_First_Widget',
      settings: {
        appearance: {
          position: 1,
          offset_from_bottom: 20,
          offset_from_left: 10,
          color_schema: 1,
          pattern: 4,
          gradient: 4,
          theme_color: '#0ff5c1',
          button_color: '#cf30e0'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    id = JSON.parse(@response.body)['id']
    widget.reload

    match_json(widget_show_pattern(widget))
    assert widget.settings[:appearance][:position] == request_params[:settings][:appearance][:position]
    assert widget.settings[:appearance][:offset_from_bottom] == request_params[:settings][:appearance][:offset_from_bottom]
    assert widget.settings[:appearance][:offset_from_left] == request_params[:settings][:appearance][:offset_from_left]
    assert widget.settings[:appearance][:color_schema] == request_params[:settings][:appearance][:color_schema]
    assert widget.settings[:appearance][:pattern] == request_params[:settings][:appearance][:pattern]
    assert widget.settings[:appearance][:gradient] == request_params[:settings][:appearance][:gradient]
    assert widget.settings[:appearance][:theme_color] == request_params[:settings][:appearance][:theme_color]
    assert widget.settings[:appearance][:button_color] == request_params[:settings][:appearance][:button_color]
  end

  def test_update_all_settings
    widget = create_widget
    request_params = {
      name: 'My_First_Widget',
      settings: {
        message: 'Welcome to our site',
        button_text: 'Contact',
        contact_form: {
          form_type: 1,
          form_title: 'Talk to us !',
          form_submit_message: 'Your message is sent!',
          screenshot: true,
          attach_file: false,
          captcha: false
        },
        appearance: {
          position: 1,
          offset_from_bottom: 40,
          offset_from_left: 20,
          color_schema: 1,
          pattern: 3,
          gradient: 2,
          theme_color: '#0f45c1',
          button_color: '#cc30b0'
        },
        predictive_support: {
          welcome_message: "Hi I'm Lisa",
          message: 'what is the problem ?',
          success_message: 'Thank you ji'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    id = JSON.parse(@response.body)['id']
    widget.reload

    match_json(widget_show_pattern(widget))
    assert widget.name == request_params[:name]
    assert widget.settings[:message] == request_params[:settings][:message]
    assert widget.settings[:button_text] == request_params[:settings][:button_text]
    assert widget.settings[:contact_form][:form_type] == request_params[:settings][:contact_form][:form_type]
    assert widget.settings[:contact_form][:form_title] == request_params[:settings][:contact_form][:form_title]
    assert widget.settings[:contact_form][:form_submit_message] == request_params[:settings][:contact_form][:form_submit_message]
    assert widget.settings[:contact_form][:screenshot] == request_params[:settings][:contact_form][:screenshot]
    assert widget.settings[:contact_form][:attach_file] == request_params[:settings][:contact_form][:attach_file]
    assert widget.settings[:contact_form][:captcha] == request_params[:settings][:contact_form][:captcha]
    assert widget.settings[:appearance][:position] == request_params[:settings][:appearance][:position]
    assert widget.settings[:appearance][:offset_from_bottom] == request_params[:settings][:appearance][:offset_from_bottom]
    assert widget.settings[:appearance][:offset_from_left] == request_params[:settings][:appearance][:offset_from_left]
    assert widget.settings[:appearance][:color_schema] == request_params[:settings][:appearance][:color_schema]
    assert widget.settings[:appearance][:pattern] == request_params[:settings][:appearance][:pattern]
    assert widget.settings[:appearance][:gradient] == request_params[:settings][:appearance][:gradient]
    assert widget.settings[:appearance][:theme_color] == request_params[:settings][:appearance][:theme_color]
    assert widget.settings[:appearance][:button_color] == request_params[:settings][:appearance][:button_color]
    assert widget.settings[:predictive_support][:welcome_message] == request_params[:settings][:predictive_support][:welcome_message]
    assert widget.settings[:predictive_support][:message] == request_params[:settings][:predictive_support][:message]
    assert widget.settings[:predictive_support][:success_message] == request_params[:settings][:predictive_support][:success_message]
  end

  def test_create_with_no_product_associated
    request_params = {
      product_id: nil,
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(Account.current.help_widgets.find_by_id(id)))
  end

  def test_create_with_product_associated
    product = create_product(portal_url: Faker::Avatar.image)
    request_params = {
      product_id: product.id,
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(Account.current.help_widgets.find_by_id(id)))
  end

  def test_create_with_name
    request_params = {
      product_id: nil,
      name: 'Best_Widget',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(Account.current.help_widgets.find_by_id(id)))
  end

  def test_create_with_invalid_fields
    request_params = {
      product_id: nil,
      settings: {
        components: {
          contact_form: true
        }
      },
      product_name: 'Flower'
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:product_name, 'Unexpected/invalid field in request', code: 'invalid_field')])
  end

  def test_create_with_invalid_component_fields
    request_params = {
      product_id: nil,
      settings: {
        components: {
          contact_form: true,
          gender: 'male'
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:request_params, 'Invalid components hash with gender', code: 'invalid_value')])
  end

  def test_create_with_invalid_product_associated
    request_params = {
      product_id: 100,
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern(:product_id, 'The product matching the given product_id is inaccessible to you', code: 'inaccessible_value')])
  end

  def test_config_upload_for_create
    request_params = {
      product_id: nil,
      name: 'Best_Widget',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    sidekiq_inline do
      post :create, construct_params(version: 'v2', help_widget: request_params)
    end
    assert_response 201
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(Account.current.help_widgets.find_by_id(id)))
    # file_path = HelpWidget::FILE_PATH % { :widget_id => id }
    # bucket = S3_CONFIG[:bucket]
    # assert AwsWrapper::S3Object.exists?(file_path, bucket)
  end

  def test_config_upload_for_delete
    widget = create_widget
    sidekiq_inline do
      delete :destroy, controller_params(version: 'v2', id: widget.id)
    end
    assert_response 204
    deleted_widget = Account.current.help_widgets.find(widget.id)
    refute deleted_widget.active
  end

  def test_config_upload_failure_for_create
    AwsWrapper::S3Object.stubs(:store).raises(RuntimeError)
    request_params = {
      product_id: nil,
      name: 'Best_Widget',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    sidekiq_inline do
      post :create, construct_params(version: 'v2', help_widget: request_params)
    end
    assert_response 201
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(Account.current.help_widgets.find_by_id(id)))
    file_path = HelpWidget::FILE_PATH % { :widget_id => id }
    bucket = S3_CONFIG[:bucket]
    assert AwsWrapper::S3Object.exists?(file_path, bucket)
    AwsWrapper::S3Object.unstub(:store)
  end
end
