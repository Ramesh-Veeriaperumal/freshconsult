module ProductTestHelper

  def create_product(account, options= {})
    product = account.products.first
    return product if product

    test_email = "#{Faker::Internet.domain_word}#{rand(0..9999)}@#{account.full_domain}"
    portal_name = Faker::Company.name
    portal_url = "freshdesk."+portal_name+".com"
    test_product = FactoryGirl.build(:product, 
      :name => options[:name] || Faker::Name.name, 
      :description => Faker::Lorem.paragraph, 
      :account_id => account.id,
      :created_at => Time.now.utc,
      :updated_at => Time.now.utc
      )
    test_product.save(validate: false)

    test_email_config = FactoryGirl.build(:email_config, 
      :to_email => test_email, 
      :reply_email => test_email,
      :primary_role =>"true", 
      :name => test_product.name, 
      :product_id => test_product.id,
      :account_id => account.id,
      :active=>"true")
    test_email_config.save(validate: false)

    begin
      FactoryGirl.define do
        factory :portal, :class => Portal do
        sequence(:name) { |n| "Portal#{n}" }
        end
      end
    rescue Exception => e
    end

    test_portal = FactoryGirl.build(:portal, 
      :name=> portal_name || Faker::Name.name, 
      :portal_url => portal_url, 
      :language=>"en",
      :product_id => test_product.id, 
      :forum_category_ids => (options[:forum_category_ids] || [""]),
      :solution_category_metum_ids => [""],
      :account_id => account.id, 
      :preferences=>{ 
        :logo_link=>"", 
        :contact_info=>"", 
        :header_color=>"#252525",
        :tab_color=>"#006063", 
        :bg_color=>"#efefef" 
      })
    test_portal.save(validate: false)

    test_product
  end

  def central_publish_product_pattern(product, product_push_timestamp)
    {
      id: product.id,
      name: product.name,
      description: product.description,
      account_id: product.account_id,
      product_push_timestamp: product_push_timestamp,
      portal_id: product.portal.id,
      email_config_ids: product.email_configs.all(:select => :id).collect(&:id),
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
        arr[index] = email
      end
    end

    {
      portal: (product.portal ? product.portal.as_json["portal"] : {}),
      email_configs: arr
    }

  end

end