module ProductsHelper

	def create_product(option={})
		test_product = FactoryGirl.build(:product, :name => option[:name] || Faker::Name.name, :description => Faker::Lorem.paragraph, 
			                                   :account_id => @account.id)
		test_product.save(validate: false)
		test_email_config = FactoryGirl.build(:email_config, :to_email => option[:email], :reply_email => option[:email],
			                                             :primary_role =>"true", :name => test_product.name, :product_id => test_product.id,
			                                             :account_id => @account.id,:active=>"true")
		test_email_config.save(validate: false)

		if option[:portal_url]
			test_portal = FactoryGirl.build(:portal, 
												:name=> option[:portal_name] || Faker::Name.name, 
												:portal_url => option[:portal_url], 
												:language=>"en",
												:product_id => test_product.id, 
												:forum_category_id => (option[:forum_category_id] || ""),
												:solution_category_ids => [""],
												:account_id => @account.id,
												:preferences=>{ 
													:logo_link=>"", 
													:contact_info=>"", 
													:header_color=>"#252525",
													:tab_color=>"#006063", 
                                 		            :bg_color=>"#efefef" 
                                 		        })
			test_portal.save(validate: false)
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
            :portal_attributes=>{ :name=>option[:portal_name] || "", :portal_url=>option[:portal_url] || "", :language=>"en", :forum_category_id=>"", :solution_category_ids=>[""], 
                                  :preferences=>{ :logo_link=>"", :contact_info=>"", :header_color=> option[:header_color] || "#252525", 
                                  	              :tab_color=>"#006063", :bg_color=>option[:bg_color] || "#efefef" },
                                  :id => option[:portal_id] || ""
                                }
		}
	end
end