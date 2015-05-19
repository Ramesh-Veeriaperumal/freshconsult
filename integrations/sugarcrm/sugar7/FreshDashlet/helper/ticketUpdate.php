<?php
require_once('../../../../modules/freshdesk/FreshdeskLib.php');
//require_once('custom/clients/base/helper/SecurityHelper.php');
// PHP is default openssl_encrypt/decrypt functions are not giving a UTF-8 that can be passed via REST API.
// The alternate encrypt/functions defined in SecurityHelper needs mcrypt to be installed on the machine. Overkill solution anyways all of this happens after the user login and is not exposed to the outside world so not a problem. Creating the Stub alone here and if required can be extended.
//$obj = new SecurityHelper();

$freshdesk_domain = $_POST["fd_domain"];
$freshdesk_ssl_option = $_POST["fd_ssl"];
$freshdesk_credentials = $_POST["fd_credential"];

$field_key = $_POST["field_key"];
//jQuery 1.8 and belows sends null as a string "null" and to fix that making
//the ternary check below
$field_value = ($_POST["field_value"] == "null") ? "" : $_POST["field_value"];
$ticket_id = $_POST["ticket_id"];
$freshdesk_lib = null;
$data = null;
$response = null;

if(!empty($freshdesk_domain) && !empty($freshdesk_ssl_option) && !empty($freshdesk_credentials)) {
	$freshdesk_lib = new FreshdeskLib($freshdesk_domain, $freshdesk_credentials, $freshdesk_ssl_option);
} else {
	header('HTTP/1.0 401 Unauthorized');
    	echo 'API credentials are invalid';
}

if(!empty($field_key) && !empty($ticket_id)) {
	$data = array ("helpdesk_ticket" => array($field_key => $field_value));
} else {
	header('HTTP/1.0 404 Bad Request');
	echo 'Some fields are missing';
}

$response = $freshdesk_lib->updateTicket($data, $ticket_id);
echo $response;
?>
