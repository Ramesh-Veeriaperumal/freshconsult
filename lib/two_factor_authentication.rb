#include this module and it does following things
#1. send_otp_via_mail - sends one time password to the email given
#2. validate_otp will validate the user entered otp with user's actual otp(which is valid for 5 mins only)
#3. generate_otp will generate an otp 
module TwoFactorAuthentication

	include Redis::RedisKeys
	include Redis::OthersRedis
	FIVE_MINUTES = 300

	def send_otp_via_mail(email)
		otp = generate_otp
		text = t('one_time_password_instructions', :otp => otp)
		set_others_redis_key(USER_OTP_KEY % {:email => email},otp,FIVE_MINUTES)
		Rails.logger.silence do
			UserNotifier.one_time_password(email,text)
		end
	end

	def generate_otp
		1_000_000 + Random.rand(10_000_000 - 1_000_000)
	end

	def validate_otp(email,user_otp)
		actual_otp(email).to_i == user_otp.to_i
	end

	def clear_otp(email)
		remove_others_redis_key(USER_OTP_KEY % {:email => email})
	end

	def actual_otp(email)
		get_others_redis_key(USER_OTP_KEY % {:email => email})
	end

	def otp_exists?(email)
		exists?(USER_OTP_KEY % {:email => email})
	end
end