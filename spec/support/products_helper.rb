module ProductsHelper

	def create_product(option={})
		defaults = {
			:email => "#{Faker::Internet.domain_word}@#{@account.full_domain}",
			:portal_name => Faker::Company.name
		}

		option = option.merge(defaults) { |key, v1, v2| v1 }

		test_product = Factory.build(:product, :name => option[:name] || Faker::Name.name, :description => Faker::Lorem.paragraph, 
			                                   :account_id => @account.id)
		test_product.save(false)
		test_email_config = Factory.build(:email_config, :to_email => option[:email], :reply_email => option[:email],
			                                             :primary_role =>"true", :name => test_product.name, :product_id => test_product.id,
			                                             :account_id => @account.id,:active=>"true")
		test_email_config.save(false)

		if option[:portal_url]
			test_portal = Factory.build(:portal, 
												:name=> option[:portal_name] || Faker::Name.name, 
												:portal_url => option[:portal_url], 
												:language=>"en",
												:product_id => test_product.id, 
												:forum_category_ids => (option[:forum_category_ids] || [""]),
												:solution_category_ids => [""],
												:account_id => @account.id,
												:preferences=>{ 
													:logo_link=>"", 
													:contact_info=>"", 
													:header_color=>"#252525",
													:tab_color=>"#006063", 
                                 		            :bg_color=>"#efefef" 
                                 		        })
			test_portal.save(false)
		end
		test_product
	end

	def product_params(option={})
		{
			:name => option[:name], :description => option[:description] || Faker::Lorem.paragraph, 
			:email_configs_attributes=>{ "0"=>{ :reply_email =>option[:email] || "", :primary_role =>"true", :_destroy=>"false", 
			                         		   :to_email=>option[:email] || "",:group_id=>"", :id => option[:email_configs_id] || "" }
                                        }, 
            :enable_portal=> option[:enable_portal] || "1", 
            :portal_attributes=>{ :name=>option[:portal_name] || "", :portal_url=>option[:portal_url] || "", :language=>"en", :forum_category_ids=>[""], :solution_category_ids=>[""], 
                                  :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=> option[:header_color] || "#252525", 
                                  	              :tab_color=>"#006063", :bg_color=>option[:bg_color] || "#efefef" },
                                  :id => option[:portal_id] || ""
                                }
		}
	end
end