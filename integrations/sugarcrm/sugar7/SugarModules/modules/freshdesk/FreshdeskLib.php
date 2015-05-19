<?php

/** Freshdesk PHP Library **/

class FreshdeskLib {

	var $response, $response_headers;
	private $domain, $credentials, $https;
	private $connection;

	function FreshdeskLib($domain, $credentials, $secure_connection = false) {
		
		$this->domain = $domain ;

		$this->credentials = $credentials;
		$this->https = $secure_connection;
	}

	function getTicketsByEmail($email,$filter_name='all_tickets', $page = 1) {
		return $this->_get("/helpdesk/tickets.json?filter_name=$filter_name&page=$page&email=".($email));
	}

	function getTicketsByCompanyName($name,$filter_name='all_tickets', $page = 1) {
		return $this->_get("/helpdesk/tickets.json?filter_name=$filter_name&page=$page&company_name=".urlencode($name));
	}

	function getTickets() {
		return $this->_get("/helpdesk/tickets.json");
	}

	function getTicketFields() {
		return $this->_get("/ticket_fields.json");
	}
	
	function updateTicket($data, $ticket_id) {
		return $this->_put("/helpdesk/tickets/".$ticket_id.".json", $data);
	}

	private function request($full_url, $method = 'GET', $data = null) {
		$connection = $this->connection();

		switch ($method) {
			case 'POST':
				curl_setopt($connection, CURLOPT_POST, 1);
				curl_setopt($connection, CURLOPT_POSTFIELDS, http_build_query($data));
				break;
			case 'PUT':
				curl_setopt($connection, CURLOPT_CUSTOMREQUEST, "PUT");
				curl_setopt($connection, CURLOPT_POSTFIELDS, http_build_query($data));
				break;
		}

		//curl_setopt($connection, CURLOPT_VERBOSE, $full_url);
		curl_setopt($connection, CURLOPT_URL, $full_url);

		$this->response = curl_exec($connection);
		//print_r($this->response);
		$this->response_headers['http_code'] = curl_getinfo($connection,CURLINFO_HTTP_CODE);
		$this->response_headers['error']['code'] = curl_errno($connection);
		$this->response_headers['error']['message'] = curl_error($connection);

		if ($this->response_headers['http_code'] >= 300) {
			return false;
			//Redirections are also considered as error.
		}
		return $this->response;
	}

	private function connection() {
		if (is_null($this->connection)) {
			$this->connection = curl_init();
			curl_setopt($this->connection, CURLOPT_RETURNTRANSFER, true);
			curl_setopt($this->connection, CURLOPT_FOLLOWLOCATION, false);
			curl_setopt($this->connection, CURLOPT_HEADER, false);
			curl_setopt($this->connection, CURLOPT_USERPWD, $this->_auth());

			$headers = array(
				'Accept: application/json',
				'Content-Type: application/json'
			);
		}

		return $this->connection;
	}

	private function _put($url, $data) {
		$this->request($this->_url($url), 'PUT', $data);
	}

	private function _get($url) {
		$got_json = $this->request($this->_url($url),'GET');
		return $this->_toObject($this->request($this->_url($url),'GET'));
	}

	private function _url($url) {
		$constructed_url = ($this->https ? "https://" : "http://") . $this->_properDomain() . $url;
		return ( $this->https ? "https://" : "http://") . $this->_properDomain() . $url;
	}

	private function _auth() {
		return is_array($this->credentials) ?  ($this->credentials['username'].':'.$this->credentials['password']) : (trim($this->credentials) . ": ");
	}

	private function _xmlToObject($xml_string) {
		try {
			$output = new SimpleXMLElement($xml_string);
		} catch(Exception $e) {
			 $output = new stdClass();
		}
		
		// $output = trim($xml_string);
		return $output;
	}


	private function _toObject($json_string) {
		try {
			$output = json_decode($json_string);
		} catch(Exception $e) {
			 $output = new stdClass();
		}
		return $output;
	}


	function _properDomain() {

		$allowedSpecialDomains = array(
			'localhost',
			'localhost:3000',
			'localbala.ngrok.com',
		);
		return in_array($this->domain, $allowedSpecialDomains) ? $this->domain : (strstr($this->domain,'.') ? $this->domain : $this->domain.'.freshdesk.com');
	}

}

