<?php
/** author: bala
 *  Writing it as a helper to encrypt the FD domain, api key and other config options and decrypt the same as and when needed.
 *  Idea is from http://stackoverflow.com/questions/16600708/php-string-encrypt-and-decrypt
 */

class SecurityHelper
{
	
	public $password;
	public $method;
	public $iv;

	function SecurityHelper()
	{
		$this->password = "freshdesk_sugar";
		$this->method = "aes128";
		$this->iv = "freshdesk_init_v";
	}
	/**
	 * Returns an encrypted & utf8-encoded
	 */
	public function encrypt($pure_string, $encryption_key) {
	    $iv_size = mcrypt_get_iv_size(MCRYPT_BLOWFISH, MCRYPT_MODE_ECB);
	    $iv = mcrypt_create_iv($iv_size, MCRYPT_RAND);
	    $encrypted_string = mcrypt_encrypt(MCRYPT_BLOWFISH, $encryption_key, utf8_encode($pure_string), MCRYPT_MODE_ECB, $iv);
	    return $encrypted_string;
	}

	/**
	 * Returns decrypted original string
	 */
	public function decrypt($encrypted_string, $encryption_key) {
	    $iv_size = mcrypt_get_iv_size(MCRYPT_BLOWFISH, MCRYPT_MODE_ECB);
	    $iv = mcrypt_create_iv($iv_size, MCRYPT_RAND);
	    $decrypted_string = mcrypt_decrypt(MCRYPT_BLOWFISH, $encryption_key, $encrypted_string, MCRYPT_MODE_ECB, $iv);
	    return $decrypted_string;
	}
}

?>


