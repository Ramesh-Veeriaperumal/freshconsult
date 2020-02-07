require_relative '../../../api/test_helper'
require_relative '../../../models/helpers/product_test_helper'

class Admin::ProductsControllerTest < ActionController::TestCase
  include Email::Mailbox::Utils
  include ProductTestHelper
  include AccountHelper

  def test_validate_params_on_create
    account = create_account.make_current
    reply_email = Faker::Internet.email
    post :create,
         product: product_params(name: 'New_product', reply_email: reply_email, to_email: "#{Faker::Internet.domain_word}@#{@account.full_domain}")
    new_product = account.products.find_by_name('New_product')
    email_config = new_product.email_configs.where(reply_email: reply_email)
    to_email = construct_to_email(reply_email, account.full_domain)
    assert_equal to_email, email_config.pluck(:to_email).first
  end

  def test_validate_params_on_update
    account = create_account.make_current
    reply_email = Faker::Internet.email
    test_product = create_product(account)
    test_product_id = test_product.email_configs.first.id
    put :update,
        id: test_product.id,
        product: { name: test_product.name,
                   description: test_product.description,
                   email_configs_attributes: {
                     '0' => { id: test_product.email_configs.first.id,
                              reply_email: test_product_id,
                              primary_role: 'true',
                              _destroy: 'false',
                              to_email: "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                              group_id: '' },
                     '1' => { id: '',
                              reply_email: reply_email,
                              primary_role: 'true',
                              _destroy: 'false',
                              to_email: "#{Faker::Internet.domain_word}@#{@account.full_domain}",
                              group_id: '' }
                   } }
    added_to_email = construct_to_email(reply_email, account.full_domain)
    email_config = test_product.email_configs.where(reply_email: reply_email)
    assert_equal added_to_email, email_config.pluck(:to_email).first
    email_config = test_product.email_configs.where(id: test_product_id)
    existing_to_email = construct_to_email(email_config.pluck(:reply_email).first, account.full_domain)
    assert_equal existing_to_email, email_config.pluck(:to_email).first
  end

  private

    def product_params(option = {})
      {
        name: option[:name], description: option[:description] || Faker::Lorem.paragraph,
        email_configs_attributes: { '0' => { reply_email: option[:reply_email] || '', primary_role: 'true', _destroy: 'false',
                                             to_email: option[:to_email] || '', group_id: '', id: option[:email_configs_id] || '' } }
      }
    end

    def create_account
      Account.first.presence || create_test_account
    end
end
