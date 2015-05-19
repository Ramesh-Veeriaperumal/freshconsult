<?php
/** This file has the required helper method to read the config values that are related to Freshdesk from the DB.
*/
class FreshdeskHelper {

	var $admin;

	function FreshdeskHelper()
	{
		$this->admin = new Administration();
		$this->admin->retrieveSettings('freshdesk');
	}

	function getSettings($name) {
                return $this->admin->settings['freshdesk_' . $name ];
        }	
}
