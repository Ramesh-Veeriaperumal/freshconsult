require_relative '../test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class HelpWidgetsControllerTest < ActionController::TestCase
  include HelpWidgetsTestHelper
  include FreshmarketerTestHelper
  include ProductsHelper
  include CoreSolutionsTestHelper
  include AccountTestHelper

  ALL_FM_METHODS = [:create_experiment, :enable_predictive_support, :disable_predictive_support, :enable_integration,
                    :disable_integration, :cdn_script, :create_account, :associate_account, :domains].freeze

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    @account.add_feature(:multi_product)
  end

  def stub_freshmarketer_client(methods = ALL_FM_METHODS)
    methods.each do |m|
      safe_send("stub_#{m}")
    end
    stub_connection
  end

  def unstub_freshmarketer_client
    unstub_connection
  end

  def set_widget_count
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_count] = 7
    additional_settings.save
  end

  def reset_widget_count
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings.delete(:widget_count)
  end

  def test_plan_based_widget_features_sprout
    sub_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:sprout_jan_17])
    SubscriptionPlan.stubs(:find_by_name).returns(sub_plan)
    create_sample_account('sprouttest', 'sprouttest@freshdesk.test')
    assert @account.features?(:help_widget)
    refute @account.features?(:help_widget_appearance)
    refute @account.features?(:help_widget_predictive)
  ensure
    SubscriptionPlan.unstub(:find_by_name)
    @account.destroy
  end

  def test_plan_based_widget_features_blossom
    sub_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:blossom_jan_17])
    SubscriptionPlan.stubs(:find_by_name).returns(sub_plan)
    create_sample_account('blossomtest', 'blossomtest@freshdesk.test')
    assert @account.features?(:help_widget)
    assert @account.features?(:help_widget_appearance)
    refute @account.features?(:help_widget_predictive)
  ensure
    SubscriptionPlan.unstub(:find_by_name)
    @account.destroy
  end

  def test_plan_based_widget_features_garden
    sub_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:garden_jan_17])
    SubscriptionPlan.stubs(:find_by_name).returns(sub_plan)
    create_sample_account('gardentest', 'gardentest@freshdesk.test')
    assert @account.features?(:help_widget)
    assert @account.features?(:help_widget_appearance)
    assert @account.features?(:help_widget_predictive)
  ensure
    SubscriptionPlan.unstub(:find_by_name)
    @account.destroy
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

  def test_index_with_count
    set_widget_count
    Account.current.help_widgets.destroy_all
    create_widget
    get :index, controller_params(version: 'v2')
    pattern = []
    Account.current.help_widgets.active.all.each do |help_widget|
      pattern << widget_list_pattern(help_widget)
    end
    assert_response 200
    assert_equal response.api_meta[:limit], 7
    assert_equal response.api_meta[:count], 1
    match_json(pattern)
    reset_widget_count
  end

  def test_index_with_count_without_widget
    set_widget_count
    Account.current.help_widgets.destroy_all
    get :index, controller_params(version: 'private')
    pattern = []
    Account.current.help_widgets.active.all.each do |help_widget|
      pattern << widget_list_pattern(help_widget)
    end
    assert_response 200
    assert_equal response.api_meta[:limit], 7
    assert_equal response.api_meta[:count], 0
    match_json(pattern)
    reset_widget_count
  end

  def test_index_sprout
    Subscription.any_instance.stubs(:sprout?).returns(true)
    create_widget
    get :index, controller_params(version: 'v2')
    pattern = []
    Account.current.help_widgets.active.all.each do |help_widget|
      pattern << widget_list_pattern(help_widget)
    end
    assert_response 200
    assert_equal response.api_meta[:limit], 1
    match_json(pattern)
    Subscription.any_instance.unstub(:sprout?)
  end

  def test_index_non_sprout
    Subscription.any_instance.stubs(:sprout?).returns(false)
    create_widget
    get :index, controller_params(version: 'v2')
    pattern = []
    Account.current.help_widgets.active.all.each do |help_widget|
      pattern << widget_list_pattern(help_widget)
    end
    assert_response 200
    assert_equal response.api_meta[:limit], 10
    match_json(pattern)
    Subscription.any_instance.unstub(:sprout?)
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

  def test_show_with_solution_category_ids
    help_widget = create_widget
    category = build_solution_categories(help_widget)
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 200
    assert_equal [category.id], JSON.parse(@response.body)['solution_category_ids']
    match_json(widget_show_pattern(help_widget))
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
    @account.remove_feature(:help_widget)
    get :show, controller_params(version: 'v2', id: help_widget.id)
    assert_response 403
    @account.add_feature(:help_widget)
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
    assert_nil Account.current.help_widgets.where(id: help_widget.id).first
  end

  def test_soft_delete_with_predictive_support
    link_freshmarketer_account
    stub_freshmarketer_client
    help_widget = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', help_widget.id)
    additional_settings.save
    help_widget.settings[:components][:predictive_support] = true
    help_widget.settings[:predictive_support][:domain_list] = ['test.fresh.com', 'test1.fresh.com']
    help_widget.save
    delete :destroy, controller_params(version: 'v2', id: help_widget.id)
    assert_response 204
    assert_nil Account.current.help_widgets.where(id: help_widget.id).first
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == []
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
    match_json(widget_show_pattern(widget))
    assert widget.settings[:appearance][:theme_color] == request_params[:settings][:appearance].fetch('theme_color')
    assert widget.settings[:appearance][:button_color] == request_params[:settings][:appearance].fetch('button_color')
  end

  def test_update_appearance_text_color
    widget = create_widget
    request_params = {
      settings: {
        appearance: {
          'theme_text_color' => '#000000',
          'button_text_color' => '#000000'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    match_json(widget_show_pattern(widget))
    assert widget.settings[:appearance][:theme_text_color] == request_params[:settings][:appearance].fetch('theme_text_color')
    assert widget.settings[:appearance][:button_text_color] == request_params[:settings][:appearance].fetch('button_text_color')
  end

  def test_update_appearance_invalid_text_color
    widget = create_widget
    request_params = {
      settings: {
        appearance: {
          'theme_text_color' => '#000f00',
          'button_text_color' => '#e00000'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('settings', 'theme_text_color', "It should be one of these values: '#ffffff,#000000'", code: :invalid_value)])
  end

  def test_update_appearance_invalid_text_color_format
    widget = create_widget
    request_params = {
      settings: {
        appearance: {
          'theme_text_color' => '000000',
          'button_text_color' => '000000'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json([bad_request_error_pattern_with_nested_field('settings', 'theme_text_color', 'It should be in the \'accepted #{attribute}\' format', code: 'invalid_value')])
  end

  def test_update_solution_category_ids
    widget = create_widget
    build_solution_categories(widget)
    new_category = create_category
    request_params = {
      solution_category_ids: [new_category.id]
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    match_json(widget_show_pattern(widget))
    assert_equal [new_category.id], JSON.parse(@response.body)['solution_category_ids']
  end

  def test_update_invalid_solution_category_ids
    widget = create_widget
    request_params = {
      solution_category_ids: [100]
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:solution_category_ids, 'Please specify valid solution category ids.', code: 'invalid_value')))
  end

  def test_update_appearance_without_feature
    @account.remove_feature(:help_widget_appearance)
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
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:appearance, :require_feature, feature: :help_widget_appearance)))
    @account.add_feature(:help_widget_appearance)
  end

  def test_update_predictive_without_feature
    @account.remove_feature(:help_widget_predictive)
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern(:predictive_support, :require_feature, feature: :help_widget_predictive)))
    @account.add_feature(:help_widget_predictive)
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
    match_json([bad_request_error_pattern_with_nested_field('settings', 'theme_color', 'It should be in the \'accepted #{attribute}\' format', code: 'invalid_value')])
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

  def test_update_with_require_login
    widget = create_widget
    params_hash = widget_hash(widget)
    request_params = {
      settings: {
        contact_form: {
          require_login: true
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.contact_form_require_login?
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

  def test_update_with_solution_articles_enabled_contact_form_disabled
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

  #--------------- Predictive Support Cases - START --------------------#

  def test_update_with_fm_account_create
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:components][:predictive_support] == true
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['test.fresh.co'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.co'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_create_predictive_off
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: false
        },
        predictive_support: {
          domain_list: ['test.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
  end

  def test_update_with_fm_account_create_mismatch
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'link'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_create_mismatch_predictive_disabled
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: false
        },
        predictive_support: {
          domain_list: ['test.com']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'link'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_create_conflict_error
    stub_freshmarketer_client([:resource_conflict_error_response])
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['kalai.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 409
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_create_bad_request_error
    stub_freshmarketer_client([:bad_request_error_response])
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['padhu.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 400
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_create_internal_server_error
    stub_freshmarketer_client([:internal_server_error_response])
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['ranjani.fresh.co']
        }
      },
      freshmarketer: {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 500
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_link
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['test.fresh']
        }
      },
      freshmarketer: {
        domain: 'test1.fmstack.com',
        type: 'associate'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:components][:predictive_support] == true
    freshmarketer_hash = Account.current.account_additional_settings.additional_settings[:freshmarketer]
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert_nil freshmarketer_hash[:acc_id]
    assert fm_widget_hash['test.fresh'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
  end

  def test_update_with_fm_account_link_with_support_domain
    stub_freshmarketer_client
    widget = create_widget
    request_params = {
      settings: {
        components: {
          predictive_support: true
        },
        predictive_support: {
          domain_list: ['localhost.freshpo.com']
        }
      },
      freshmarketer: {
        domain: 'test2.fmstack.com',
        type: 'associate'
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:components][:predictive_support] == true
    freshmarketer_hash = Account.current.account_additional_settings.additional_settings[:freshmarketer]
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert_present freshmarketer_hash[:acc_id]
    assert fm_widget_hash['localhost.freshpo.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['localhost.freshpo.com'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
  end

  def test_update_with_invalid_domain
    widget = create_widget
    link_freshmarketer_account
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
    link_freshmarketer_account
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
    unlink_freshmarketer_account
  end

  def test_update_without_predictive_with_domain_list
    link_freshmarketer_account
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
    unlink_freshmarketer_account
  end

  def test_update_domain_list_to_empty
    link_freshmarketer_account
    widget = create_widget
    widget.settings[:components][:predictive_support] = true
    widget.settings[:predictive_support][:domain_list] = ['test.fresh.com']
    widget.save
    request_params = {
      settings: {
        predictive_support: {
          domain_list: []
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    match_json(validation_error_pattern(bad_request_error_pattern(:domain_list, 'Please specify URLs to track for predictive support.', code: 'invalid_value')))
    assert_response 400
    unlink_freshmarketer_account
  end

  def test_update_with_more_than_three_domain
    link_freshmarketer_account
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
    match_json(validation_error_pattern(bad_request_error_pattern_with_nested_field(:settings, :domain_list, 'Has 4 values, it can have maximum of 3 values', code: 'invalid_value')))
    assert_response 400
    unlink_freshmarketer_account
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
    unlink_freshmarketer_account
  end

  def test_update_widget_with_already_existing_fm_domain
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    settings = Account.current.account_additional_settings
    settings.additional_settings[:widget_predictive_support] = fm_widget_hash.merge(
      'test.fresh.com' => {
        exp_id: '4151515152505F435F415C51405F594C5C5A5F5F',
        widget_ids: [100]
      }
    )
    settings.save
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
    assert fm_widget_hash['test.fresh.com'] == { exp_id: '4151515152505F435F415C51405F594C5C5A5F5F', widget_ids: [100, widget.id] }
    unstub_freshmarketer_client
    unlink_freshmarketer_account
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
          domain_list: ['test.fresh.com', 'test2.fresh.com']
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    widget.reload
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(widget))
    assert widget.settings[:predictive_support][:domain_list] == ['test.fresh.com', 'test2.fresh.com']
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == [widget.id]
    assert fm_widget_hash['test2.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test2.fresh.com'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
    unlink_freshmarketer_account
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == [widget.id]
    refute fm_widget_hash.key?('TEST.FRESH.COM')
    unstub_freshmarketer_client
    unlink_freshmarketer_account
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
    unlink_freshmarketer_account
  end

  def test_update_remove_domain_list
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', widget.id)
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == []
    assert fm_widget_hash['test.fresh1.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh1.com'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
    unlink_freshmarketer_account
  end

  def test_update_remove_domain_list_with_predictive_enabled
    link_freshmarketer_account
    stub_freshmarketer_client
    widget = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', widget.id)
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F' # errrrr
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == [widget.id]
    assert fm_widget_hash['test.fresh1.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh1.com'][:widget_ids] == [widget.id]
    unstub_freshmarketer_client
    unlink_freshmarketer_account
  end

  def test_update_remove_domain_and_disable_predictive_support
    widget = create_widget
    link_freshmarketer_account
    stub_freshmarketer_client
    fm_widget_hash = Account.current.account_additional_settings.widget_predictive_support_hash
    settings = Account.current.account_additional_settings
    settings.additional_settings[:widget_predictive_support] = fm_widget_hash.merge(
      'test.fresh.com' => {
        exp_id: '4151515152505F435F415C51405F594C5C5A5F5F',
        widget_ids: [100, widget.id]
      }
    )
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == [100]
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_disable_predictive_support
    widget = create_widget
    link_freshmarketer_account
    stub_freshmarketer_client
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', widget.id)
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
    assert fm_widget_hash['test.fresh.com'][:exp_id] == '4151515152505F435F415C51405F594C5C5A5F5F'
    assert fm_widget_hash['test.fresh.com'][:widget_ids] == []
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_predictive_support_with_fm_error_enable_predictive_support
    link_freshmarketer_account
    stub_freshmarketer_client([:create_experiment, :enable_predictive_support_error, :disable_predictive_support, :enable_integration,
                               :disable_integration, :cdn_script])
    widget1 = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', widget1.id)
    additional_settings.save
    widget1.settings[:components][:predictive_support] = true
    widget1.settings[:predictive_support][:domain_list] = ['test.fresh.com']
    widget1.save
    widget2 = create_widget
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
    put :update, construct_params(version: 'v2', id: widget2.id, help_widget: request_params)
    assert_response 500
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_predictive_support_with_fm_error_enable_predictive_integration
    link_freshmarketer_account
    stub_freshmarketer_client([:create_experiment,
                               :enable_predictive_support,
                               :disable_predictive_support,
                               :enable_integration_error,
                               :disable_integration,
                               :cdn_script])
    widget1 = create_widget
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', widget1.id)
    additional_settings.save
    widget1.settings[:components][:predictive_support] = true
    widget1.settings[:predictive_support][:domain_list] = ['test.fresh.com']
    widget1.save
    widget2 = create_widget
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
    put :update, construct_params(version: 'v2', id: widget2.id, help_widget: request_params)
    assert_response 500
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_predictive_support_with_fm_error_create_experiment
    link_freshmarketer_account
    stub_freshmarketer_client(([:create_experiment_error, :enable_predictive_support, :disable_predictive_support, :enable_integration,
                                :disable_integration, :cdn_script]))
    stub_create_experiment_error
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
    assert_response 500
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_predictive_support_with_fm_error_disable_integration
    widget = create_widget
    link_freshmarketer_account
    stub_freshmarketer_client([:create_experiment, :enable_predictive_support, :disable_predictive_support, :enable_integration,
                               :disable_integration_error, :cdn_script])
    stub_disable_integration_error
    additional_settings = Account.current.account_additional_settings
    additional_settings.additional_settings[:widget_predictive_support] = fm_widget_settings('test.fresh.com', widget.id)
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
    assert_response 500
    unlink_freshmarketer_account
    unstub_freshmarketer_client
  end

  def test_update_predictive_support_with_fm_error_disable_predictive_support
    link_freshmarketer_account
    stub_freshmarketer_client([:create_experiment, :enable_predictive_support, :disable_predictive_support_error, :enable_integration,
                               :disable_integration, :cdn_script])
    save_freshmarketer_hash(
      account_id: '4151515152505F435F415C51405F594C5C5A5F5F',
      authtoken: '1taehlg306k6bl88vpq44500970cmuuufnrq86br',
      cdnscript: "<script src=\'//s3-us-west-2.amazonaws.com/zargetlab-js-bucket/48434356339/1300.js\'></script>",
      app_url: 'http://sr.pre-freshmarketer.io/ab/#/org/45701089031/project/914/experiment/1406/session/sessions',
      integrate_url: 'http://sr.pre-freshmarketer.io/ab/#/org/45701089031/project/914/settings/#/apikey'
    )
    widget = create_widget
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
    assert_response 500
    unstub_freshmarketer_client
  end

  #--------------- Predictive Support Cases - END --------------------#

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

  def test_update_invalid_with_empty_settings_hash
    widget = create_widget
    widget_settings = widget.settings
    request_params = {
      settings: {}
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
    assert_equal widget_settings, widget.settings
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
    link_freshmarketer_account
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
          captcha: false,
          require_login: true
        },
        appearance: {
          position: 1,
          offset_from_bottom: 40,
          offset_from_left: 20,
          color_schema: 1,
          pattern: 3,
          gradient: 2,
          theme_color: '#0f45c1',
          button_color: '#cc30b0',
          theme_text_color: '#000000',
          button_text_color: '#ffffff'
        }
      }
    }
    put :update, construct_params(version: 'v2', id: widget.id, help_widget: request_params)
    assert_response 200
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
    assert widget.contact_form_require_login?
    assert widget.settings[:appearance][:position] == request_params[:settings][:appearance][:position]
    assert widget.settings[:appearance][:offset_from_bottom] == request_params[:settings][:appearance][:offset_from_bottom]
    assert widget.settings[:appearance][:offset_from_left] == request_params[:settings][:appearance][:offset_from_left]
    assert widget.settings[:appearance][:color_schema] == request_params[:settings][:appearance][:color_schema]
    assert widget.settings[:appearance][:pattern] == request_params[:settings][:appearance][:pattern]
    assert widget.settings[:appearance][:gradient] == request_params[:settings][:appearance][:gradient]
    assert widget.settings[:appearance][:theme_color] == request_params[:settings][:appearance][:theme_color]
    assert widget.settings[:appearance][:theme_text_color] == request_params[:settings][:appearance][:theme_text_color]
    assert widget.settings[:appearance][:button_text_color] == request_params[:settings][:appearance][:button_text_color]
    unlink_freshmarketer_account
  end

  def test_widget_create_without_product
    Account.current.help_widgets.destroy_all
    constant_widget_settings_hash = HelpWidget.default_settings(nil, nil)
    request_params = {
      product_id: nil,
      name: 'First new widget',
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
    assert_equal Account.current.help_widgets.find_by_id(id).settings[:message], 'Welcome to Support'
    assert_equal constant_widget_settings_hash, HelpWidget.default_settings(nil, nil)
  end

  def test_widget_create_product_with_portal
    Account.current.help_widgets.destroy_all
    constant_widget_settings_hash = HelpWidget.default_settings(nil, nil)
    product1 = create_product(portal_url: 'sample.freshpo.com')
    portal = Account.current.portals.find_by_product_id(product1.id)
    request_params = {
      product_id: product1.id,
      name: 'First new widget',
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
    assert Account.current.help_widgets.find_by_id(id).settings[:message] == "Welcome to #{product1.name} Support"
    assert Account.current.help_widgets.find_by_id(id).settings[:appearance][:button_color] == portal.preferences[:tab_color]
    assert constant_widget_settings_hash == HelpWidget.default_settings(nil, nil)
  end

  def test_widget_create_product_without_portal
    Account.current.help_widgets.destroy_all
    constant_widget_hash = HelpWidget.default_settings(nil, nil)
    product2 = create_product
    request_params = {
      product_id: product2.id,
      name: 'Second new widget',
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
    assert Account.current.help_widgets.find_by_id(id).settings[:message] == "Welcome to #{product2.name} Support"
    assert Account.current.help_widgets.find_by_id(id).settings[:appearance][:button_color] == Account.current.main_portal.try(:preferences).try(:[], :tab_color)
    assert constant_widget_hash == HelpWidget.default_settings(nil, nil)
  end

  def test_widget_create_default_language_check
    Account.current.help_widgets.destroy_all
    user = User.first.make_current
    user.language = 'de'
    user.save
    request_params = {
      name: 'First new widget',
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
    # assert Account.current.help_widgets.find_by_id(id).settings[:button_text] == 'Ayuda'
    # assert Account.current.help_widgets.find_by_id(id).settings[:contact_form][:form_title] == 'Contactarte'
    # assert Account.current.help_widgets.find_by_id(id).settings[:contact_form][:form_button_text] == 'Enviar'
    # assert Account.current.help_widgets.find_by_id(id).settings[:contact_form][:form_submit_message] == 'Gracias por tus comentarios.'
  end

  def test_widget_create_predictive_language_check
    Account.current.help_widgets.destroy_all
    user = User.first.make_current
    user.language = 'de'
    user.save
    request_params = {
      settings: {
        components: {
          predictive_support: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    match_json(widget_show_pattern(Account.current.help_widgets.find_by_id(id)))
    # assert Account.current.help_widgets.find_by_id(id).settings[:predictive_support][:welcome_message] == '¿Podemos ayudar?'
    # assert Account.current.help_widgets.find_by_id(id).settings[:predictive_support][:predictive_message] == 'Notamos que estás atrapado. Díganos qué estaba tratando de lograr y nuestro equipo de soporte se comunicará con usted lo antes posible.'
    # assert Account.current.help_widgets.find_by_id(id).settings[:contact_form][:success_message] == 'Gracias. ¡Estaremos en contacto!'
  end

  def test_create_with_product_id_without_multi_product_feature
    Account.current.revoke_feature(:multi_product)
    Account.current.help_widgets.destroy_all
    product = create_product(portal_url: "#{Faker::Lorem.characters(7)}#{rand(999_999)}.helpwidgets.com")
    request_params = {
      product_id: product.id,
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 400
    Account.current.add_feature(:multi_product)
  end

  def test_create_with_product_associated
    Account.current.help_widgets.destroy_all
    product = create_product(portal_url: "#{Faker::Lorem.characters(7)}#{rand(999_999)}.widgets.com")
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

  def test_create_default
    product = create_product(portal_url: "#{Faker::Lorem.characters(7)}#{rand(999_999)}.helpwidget.com")
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
    widget = Account.current.help_widgets.find_by_id(id)
    match_json(widget_show_pattern(widget))
    assert widget.settings[:appearance][:theme_text_color], HelpWidget.default_settings(product, product.portal)[:appearance][:theme_text_color]
    assert widget.settings[:appearance][:button_text_color], HelpWidget.default_settings(product, product.portal)[:appearance][:button_text_color]
    widget.destroy
  end

  def test_widget_create_with_product_widget_solution_categories
    Account.current.help_widgets.destroy_all
    product1 = create_product(portal_url: 'sam1.freshpo.com')
    portal = product1.portal
    category = create_category(name: "#{Faker::Lorem.sentence(2)} .ok", description: "#{Faker::Lorem.sentence(3)}ok", is_default: false, portal_ids: [portal.id])
    request_params = {
      product_id: product1.id,
      name: 'First new widget',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    widget_category_meta_ids = Account.current.help_widgets.find(id).help_widget_solution_categories.pluck(:solution_category_meta_id)
    portal_category_meta_ids = portal.solution_category_meta.customer_categories.pluck(:id)
    assert_equal widget_category_meta_ids, portal_category_meta_ids
    assert_include widget_category_meta_ids, category.id
  end

  def test_widget_create_with_product_without_portal_solution_categories
    Account.current.help_widgets.destroy_all
    product1 = create_product
    portal = Account.current.main_portal
    category = create_category(name: "#{Faker::Lorem.sentence(2)} .ok", description: "#{Faker::Lorem.sentence(3)}ok", is_default: false, portal_ids: [portal.id])
    request_params = {
      product_id: product1.id,
      name: 'First new widget',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    widget_category_meta_ids = Account.current.help_widgets.find(id).help_widget_solution_categories.pluck(:solution_category_meta_id)
    portal_category_meta_ids = portal.solution_category_meta.customer_categories.pluck(:id)
    assert_equal widget_category_meta_ids, portal_category_meta_ids
    assert_include widget_category_meta_ids, category.id
  end

  def test_widget_create_with_no_product_widget_solution_categories
    Account.current.help_widgets.destroy_all
    portal = Account.current.main_portal
    category = create_category(name: "#{Faker::Lorem.sentence(1)} .main", description: "#{Faker::Lorem.sentence(3)}.main", is_default: false, portal_ids: [portal.id])
    request_params = {
      name: 'First new widget',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 201
    id = JSON.parse(@response.body)['id']
    widget_category_meta_ids = Account.current.help_widgets.find(id).help_widget_solution_categories.pluck(:solution_category_meta_id)
    portal_category_meta_ids = portal.solution_category_meta.customer_categories.pluck(:id)
    assert_equal widget_category_meta_ids, portal_category_meta_ids
    assert_include widget_category_meta_ids, category.id
  end

  def test_create_with_name
    Account.current.help_widgets.destroy_all
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

  def test_create_with_widget_count
    Account.current.help_widgets.destroy_all
    request_params = {
      product_id: nil,
      name: 'Widget Count',
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

  def test_create_without_count_availability
    Subscription.any_instance.stubs(:sprout?).returns(true)
    Account.current.help_widgets.destroy_all
    create_widget
    request_params = {
      product_id: nil,
      name: 'Widget Count',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    post :create, construct_params(version: 'v2', help_widget: request_params)
    assert_response 400
    match_json(request_error_pattern(:widget_limit_exceeded, widget_count: 1))
    Subscription.any_instance.unstub(:sprout?)
  end

  def test_create_with_invalid_fields
    Account.current.help_widgets.destroy_all
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
    Account.current.help_widgets.destroy_all
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
    Account.current.help_widgets.destroy_all
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
    Account.current.help_widgets.destroy_all
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
    assert_nil Account.current.help_widgets.where(id: widget.id).first
  end

  def test_config_upload_failure_for_create
    Account.current.help_widgets.destroy_all
    AwsWrapper::S3.stubs(:store).raises(RuntimeError)
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
    file_path = format(HelpWidget::FILE_PATH, widget_id: id)
    bucket = S3_CONFIG[:bucket]
    assert AwsWrapper::S3.exists?(bucket, file_path)
    AwsWrapper::S3.unstub(:store)
  end
end
