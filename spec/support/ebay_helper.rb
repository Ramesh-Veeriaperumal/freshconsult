module EbayHelper

	USER_EXTERNAL_ID = "bmkbabsat"
	ITEM_ID = "221713409273"
	MESSAGE_ID = "1030058283016"

	def create_ebay_account
		@ebay_acc = @account.ebay_accounts.build(get_ebay_configuration)
		@ebay_acc.account = @account
		@ebay_acc.email_config.account_id = @account.id
		@ebay_acc.save
	end

	def get_ebay_configuration
		{
		  :name => Faker::Lorem.sentence(2), 
		  :configs => {
		  	:app_id =>'test2b6d0-87e6-4795-ab8e-f766f22d5a7', :dev_id => "bf4eceda-896f-4639-b867-a0170444c472", 
				:auth_token => "AgAAAA**AQAAAA**aAAAAA**gwj3VA**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6AHlYOgC5WLpAmdj6x9nY+seQ**/7wCAA**AAMAAA**t30lb+F9AmvirVm0nbjEPIFB7zaw1O4+Kjv0yge0DHryFJaLvq7N6soLqlUA1mTB7M1WfmjhM8yw9ND1eG6YhbHN1mGcoGdDepicg+wo8C28DoZrr2N2+oBeICmBhuTr/ZyG4xtyVzfEn8yeuQLyLTqOcslgUlufmRAzN4MeMV6pepBhlqn9XOkykA8cHXPAhThiaCkG+8jNl8Oh2VYu+DiB0SwekBLQV/iE2g0XfB+DzcXl0nuoH35DOHCBJOlAEJ5HYJ75IXKjbM+vzLGeFor6c2aHiiLsq2Y4MuktaB+bELuN7mLZzrpvtrHtesJasFlHkEkzIKJqoQkCTiMYkNuHVv+dMzXYY1s/teqDzD9yuBaWdPPTbbF1D2xA/eAYkzHtuj0i42i7NQ2xpDFe912g+zvOaIdArzDWCOo18gnEfVUTBByeAp13CsNvMh6ZXoBcdMKK110vwunQ9lYuRyW5S9UN7NGphh4WuOOtRSnEhjs5fXBsnZjHYZq4Wi9gPjbBNr0uTJiYPgju0XVfZRFbz/tMyy+w1/j2Ibnk+n70UoMvC86wRmfv8F4PtJmSwam/ow8x21UvhakGPWat7UuIbexEa3w+fNYLRokWFKCygc0mZTq8URvXSbX/Xsy5REp04eezM+IMDzQYtGQ9+ACHFMoC9eDnWBUImd1INc5bZiS316R8rKxLrhF/YYMeV3MLAnotSJ61hNUfIOenAvOjSNAbA+lthGegpVIRXN6D/gE76fXJoDnWwdftIALF",
				:cert_id => "75c04768-11c7-43d7-91bf-8365bb43020c", :ru_name => "test-test2b6d0-87e6--sghkpzg" 
			},
			:email_config_attributes => {
				:name => Faker::Lorem.sentence(2), 
				:reply_email => Faker::Internet.email, :to_email => Faker::Internet.email, 
				:active => true 
			}
	  }
	end

	def create_ebay_item(ticket_id)
		tkt = @account.tickets.find(ticket_id)
		ebay_item = tkt.build_ebay_item(:item_id => ITEM_ID,:user_id => tkt.requester_id, 
			:message_id => MESSAGE_ID,:ebay_acc_id => @account.ebay_accounts.first.id)
		ebay_item.account_id = tkt.account_id 
		ebay_item.save
		update_user_external_id(tkt.requester_id)
	end

	def update_user_external_id(user_id)
		user = @account.users.find(user_id)
		user.user_external_id = USER_EXTERNAL_ID
    user.save
    user
	end

end