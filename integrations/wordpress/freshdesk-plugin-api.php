<?php

/* Fresdesk Api class
* Adding functionality to create ticket.
*/
class Freshdesk_Plugin_Api{

private $apikey, $domain_url, $response, $response_status;

	public function __construct($apikey, $domain_url){
		$this->apikey = $apikey;
		$this->domain_url = $domain_url;
	}	

	function create_ticket($email,$subject,$description){
		$datafields =  array (
     									"helpdesk_ticket" =>array("subject"=>$subject,"description_html"=>$description,"email"=>$email)
     								);
 		$jsondata= json_encode($datafields);
 		$this->make_request($this->domain_url."/helpdesk/tickets.json",$jsondata,$header);
 		if($this->response_status!= 200){
 			return -1;
 		}
 		return $this->response;
	}

	private function make_request($requestUri,$payload){
		$ch = curl_init ($requestUri);
 		$header[] = "Content-type: application/json";
		curl_setopt($ch, CURLOPT_POST, true);
		curl_setopt($ch, CURLOPT_POSTFIELDS,$payload);
		$user_pwd = $this->auth_method();
		// echo "value:".$user_pwd."##";
		curl_setopt($ch, CURLOPT_USERPWD,$user_pwd);
		curl_setopt($ch, CURLOPT_HTTPHEADER, $header);
		curl_setopt($ch, CURLOPT_HEADER, false);
		// receive server response ...
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
		curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_BASIC);
		curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
		curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, 0);
		$server_output = curl_exec ($ch);

		$fd_response = json_decode($server_output);
		// echo "RESPONSE:<br/>".var_dump($this->response);
		$this->response_status = curl_getinfo($ch,CURLINFO_HTTP_CODE);
		$this->response = $fd_response->{'helpdesk_ticket'}->{'display_id'};
		curl_close ($ch);
	}

	function get_response(){
		return $this->response;
	}

	function get_response_status(){
		return $this->response_status;
	}

	private function auth_method(){
		return $this->apikey.":X";
	}


}
?>