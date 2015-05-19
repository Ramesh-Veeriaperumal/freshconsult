<?php
if(!defined('sugarEntry') || !sugarEntry) die('Not A Valid Entry Point');
/*********************************************************************************
 * By installing or using this file, you are confirming on behalf of the entity
 * subscribed to the SugarCRM Inc. product ("Company") that Company is bound by
 * the SugarCRM Inc. Master Subscription Agreement (“MSA”), which is viewable at:
 * http://www.sugarcrm.com/master-subscription-agreement
 *
 * If Company is not bound by the MSA, then by installing or using this file
 * you are agreeing unconditionally that Company will be bound by the MSA and
 * certifying that you have authority to bind Company accordingly.
 *
 * Copyright (C) 2004-2013 SugarCRM Inc.  All rights reserved.
 ********************************************************************************/
require_once('include/api/SugarApi.php');
require_once 'include/SugarTheme/SidecarTheme.php';
require_once('custom/clients/base/helper/SecurityHelper.php');

class FreshdeskDashletApi extends SugarApi
{
    public function registerApiRest()
    {
        return array(
            'freshdeskdashlet' => array(
                'reqType' => 'GET',
                'path' => array('freshdeskdashlet'),
                'pathVars' => array(''),
                'method' => 'getFreshdeskDashlet',
                'shortHelp' => '',
                'longHelp' => '',
            ),
	    'ticketfields' => array(
		'reqType' => 'GET',
		'path' => array('ticketfields'),
		'pathVars' => array(''),
		'method' => 'getCustomFields',
		'shortHelp' => '',
		'longHelp' => '',
	    ),
        );
    }

	/**
	 * @param $api
	 * @param $args
	 * @return array
	 */
	public function getFreshdeskDashlet($api, $args)
	{
		$this->requireArgs($args,array('module','record'));
		$bean = $this->loadBean($api, $args);
		require_once('modules/freshdesk/FreshdeskHelper.php');
		require_once('modules/freshdesk/FreshdeskLib.php');
		// freshdeskhelper is used to fetch db config details that are in the DB.
		$freshdesk_helper = new FreshdeskHelper();
		$freshdesk_domain = $freshdesk_helper->getSettings("domain");
		$freshdesk_credentials = $freshdesk_helper->getSettings("apikey");
		$freshdesk_ssl_option = ($freshdesk_helper->getSettings("ssl") == 1 ) ? "https" : "http";
		$freshdesk_lib = new FreshdeskLib($freshdesk_domain, $freshdesk_credentials, $freshdesk_ssl_option);
		$ticket_json = null;

		// arguments can be email, account, page, filter, 
		switch($bean->object_name) {
			case "Lead":
				$ticket_json = $freshdesk_lib->getTicketsByEmail($bean->email1);
				break;
			case "Contact":
				$ticket_json = $freshdesk_lib->getTicketsByEmail($bean->email1);
				break;
			case "Account":
				$ticket_json = $freshdesk_lib->getTicketsByCompanyName($bean->name);
				break;
			default :
				$ticket_json = $freshdesk_lib->getTicketsByEmail($bean->email1);
				break;
		}
		
		$ticket_fields = $this->parseCustomFields($freshdesk_lib->getTicketFields());
		
		return array( "ticket_json" => $ticket_json, "domain" => $freshdesk_domain, "credentials" => $freshdesk_credentials, "ssl" => $freshdesk_ssl_option, "ticket_fields" => $ticket_fields);
	}
	
	public function getCustomFields($api, $args)
	{
		$this->requireArgs($args, array('module', 'record'));
		$bean = $this->loadBean($api, $args);
		require_once('modules/freshdesk/FreshdeskHelper.php');
		require_once('modules/freshdesk/FreshdeskLib.php');
		$freshdesk_helper = new FreshdeskHelper();
		$freshdesk_domain = $freshdesk_helper->getSettings("domain");
		$freshdesk_credentials = $freshdesk_helper->getSettings("apikey");
		$freshdesk_ssl_option = ($freshdesk_helper->getSettings("ssl") == 1) ? "https" : "http";
		
		$freshdesk_lib = new FreshdeskLib($freshdesk_domain, $freshdesk_credentials, $freshdesk_ssl_option);
		$raw_ticket_field_json = $freshdesk_lib->getTicketFields();
		// call the internal function that does the parsing for the custom fields.
		$ticket_field_arr = $this->parseCustomFields($raw_ticket_field_json);
		
		return array("ticket_fields" => null );
	}

	private function generateTypeNumberMap($choices)
	{
		$type_arr = array();
		foreach($choices as $choice_arr) {
			$type = $choice_arr[0];
			$map_number = $choice_arr[1];
			$type_arr[$type] = $map_number;	
		}
		return $type_arr;
	}
	
	private function parseCustomFields($custom_field_json)
	{
		$ticket_fields_arr = array("ticket_fields" => array());
		foreach($custom_field_json as $ticket_field_class) {
			$ticket_field = $ticket_field_class->ticket_field;
			$ticket_field_description = $ticket_field->description;
			$choices = $ticket_field->choices;
			switch($ticket_field_description) {
				case "Ticket status":
					$ticket_fields_arr['ticket_fields']['ticket_status'] = $this->generateTypeNumberMap($choices);
					break;
				case "Agent":
					$ticket_fields_arr['ticket_fields']['agent'] = $this->generateTypeNumberMap($choices);
					break;
				case "Ticket priority":
					$ticket_fields_arr['ticket_fields']['ticket_priority'] = $this->generateTypeNumberMap($choices);
					break;
				case "Ticket type":
					$ticket_fields_arr['ticket_fields']['ticket_type'] = $this->generateTypeNumberMap($choices);
					break;
				case "Ticket group":
					$ticket_fields_arr['ticket_fields']['ticket_group'] = $this->generateTypeNumberMap($choices);
					break;
			}
		}
		return $ticket_fields_arr;	
	}
	
}
