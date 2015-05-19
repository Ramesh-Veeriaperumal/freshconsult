<?php

require_once('include/SugarObjects/templates/basic/Basic.php');

class freshdesk extends Basic {

	var $new_schema = false;
	var $module_dir = 'freshdesk';
	var $object_name = 'freshdesk';

	function freshdesk() {
		parent::Basic();
	}

	function bean_implements($interface){
		switch($interface) {
			case 'ACL':
				return true;
				
			default:
				return false;
		}
	}
}