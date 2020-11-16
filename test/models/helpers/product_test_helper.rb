module ProductTestHelper

  def create_product(account, options= {})
    product = account.products.first
    return product if product && product.portal

    product ||= create_new_product(account, options)
    create_portal(account, product, options)
    product.reload
  end

  def create_new_product(account, options)
    test_email = "#{Faker::Internet.domain_word}#{rand(0..9999)}@#{account.full_domain}"
    test_product = FactoryGirl.build(:product,
                                     name: options[:name] || Faker::Name.name,
                                     description: Faker::Lorem.paragraph,
                                     account_id: account.id,
                                     created_at: Time.now.utc,
                                     updated_at: Time.now.utc)
    test_product.save(validate: false)

    test_email_config = FactoryGirl.build(:email_config,
                                          to_email: test_email,
                                          reply_email: test_email,
                                          primary_role: 'true',
                                          name: test_product.name,
                                          product_id: test_product.id,
                                          account_id: account.id,
                                          active: 'true')
    test_email_config.save(validate: false)

    begin
      FactoryGirl.define do
        factory :portal, :class => Portal do
        sequence(:name) { |n| "Portal#{n}" }
        end
      end
    rescue Exception => e
    end
    test_product
  end

  def create_portal(account, product, options)
    portal_name = Faker::Internet.domain_word
    portal_url = "freshdesk.#{portal_name}.com"
    test_portal = FactoryGirl.build(:portal,
                                    name: portal_name || Faker::Name.name,
                                    portal_url: portal_url,
                                    language: 'en',
                                    product_id: product.id,
                                    forum_category_ids: (options[:forum_category_ids] || ['']),
                                    solution_category_metum_ids: [''],
                                    account_id: account.id,
                                    preferences: {
                                      logo_link: '',
                                      contact_info: '',
                                      header_color: '#252525',
                                      tab_color: '#006063',
                                      bg_color: '#efefef'
                                    })
    test_portal.save(validate: false)
  end

  def central_publish_product_pattern(product, product_push_timestamp)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      account_id: product.account_id,
      #product_push_timestamp: product_push_timestamp,
      portal_id: product.portal.id,
      email_config_ids: product.email_configs.pluck(:id),
      created_at: product.created_at.try(:utc).try(:iso8601),
      updated_at: product.updated_at.try(:utc).try(:iso8601)
    }

  end

  def central_publish_product_association_pattern(product)

    arr = []
    if product.email_configs
      emails = product.email_configs.as_json
      emails.each_with_index do |config, index|
        email = config["email_config"]
        created_at = email["created_at"].try(:utc).try(:iso8601)
        updated_at = email["updated_at"].try(:utc).try(:iso8601)
        email.merge!({"created_at" => created_at, "updated_at" => updated_at})
        arr[index] = email.slice!("activator_token")
      end
    end

    {
      portal: (product.portal ? construct_portal_hash(product.portal) : {}),
      email_configs: arr
    }

  end

  def construct_portal_hash(portal)
    {
      id: portal.id,
      name: portal.name,
      product_id: portal.product_id,
      account_id: portal.account_id,
      portal_url: portal.portal_url,
      language: portal.language,
      main_portal: portal.main_portal,
      ssl_enabled: portal.ssl_enabled,
      created_at: portal.created_at,
      updated_at: portal.updated_at
    }
  end

end
