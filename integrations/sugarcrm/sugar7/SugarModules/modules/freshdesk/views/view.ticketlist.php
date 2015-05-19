<?php
if(!defined('sugarEntry') || !sugarEntry) die('Not A Valid Entry Point');

require_once('include/MVC/View/SugarView.php');
require_once('modules/freshdesk/FreshdeskUtils.php');
require_once('modules/freshdesk/lib.freshdesk.php');


class ViewTicketlist extends SugarView {

	var $focus;
	var $utils;
	var $person;
	var $freshdesk;
	var $filter;
	var $page;

	function display() {
		//Getting the Domain
		global $timedate, $app_list_strings;

		$time_format = $timedate->get_date_time_format();

		$this->person = new $_REQUEST['focus']();
		$this->person = $this->person->retrieve($_REQUEST['rec']);


		$this->ss->assign('object_type',$this->person->object_name);
		$this->ss->assign('rec',$_REQUEST['rec']);

		$this->ss->assign('settings_link',$this->constructSettingsPageLink());
		$this->utils = new FreshdeskUtils();
		$settings_domain = $this->utils->getSettings('domain');
		
		if (is_null($settings_domain) || empty($settings_domain) || trim($settings_domain) == '') {
			$this->ss->display('modules/freshdesk/tpls/not_configured.tpl');
		} else {
			$this->freshdesk = new FreshdeskLib($settings_domain, $this->utils->getSettings('apikey'),$this->utils->getSettings('ssl'));

			$this->ss->assign('url_prefix', ($this->utils->getSettings('ssl') ? "https://" : "http://" ).  $this->utils->properDomain());
			$this->ss->assign('domain_name', $this->utils->properDomain());
			$this->ss->assign('time_format',$timedate);

			$tickets = $this->getTickets();
			$this->ss->assign('object_name',$this->person->name);

			if (is_array($tickets)) {
				$data = null;
				foreach ($tickets as $tkt) {
					$ticket = new stdClass();
					$ticket->id  = (string) $tkt->display_id;
					$ticket->subject =strip_tags($tkt->subject);
					$ticket->description =strip_tags($tkt->description);
					$ticket->source =$this->utils->getSourceStr($tkt->source);

					$ticket->status = $tkt->status_name;
					$ticket->priority = $tkt->priority_name;

					$ticket->created_at = date($time_format,strtotime($tkt->{"created_at"}));
					$ticket->updated_at = date($time_format,strtotime($tkt->{"updated_at"}));
					$ticket->due_by = date($time_format,strtotime($tkt->due_by));

					$ticket->assignee = $tkt->responder_name;
					$data[] = $ticket;
				}

				$this->ss->assign('tickets', $data);
				$this->ss->assign('filter',$this->filter);
				$this->ss->assign('page', $this->page);
				if ($this->page > 1) {
					$this->ss->assign('prev_page',$this->page - 1);
				}
				if (count($data) >= 30) {
					$this->ss->assign('next_page',$this->page + 1);
				}
				$this->ss->assign('ticket_count',count($data));
				$this->ss->assign('object_type',$this->person->object_name);
				$this->ss->assign('fd_ticket_list_link',$this->constructFDTicketListLink());
				$this->ss->assign('response','');

				$this->ss->display('modules/freshdesk/tpls/ticket_list.tpl');
			} else {
				$this->ss->assign('no_email_found',$tickets === false);
				$this->ss->assign('response',$tickets);
				$this->ss->display('modules/freshdesk/tpls/tkts_error.tpl');
			}
		}
		
	}

	function getTickets() {

		$allowedFilters = array('unresolved','all_tickets');
		$this->filter = (in_array($_GET['filter'], $allowedFilters) ) ? $_GET['filter'] : 'all_tickets'; 
		$this->page = (isset($_GET['page']) && $_GET['page'] > 0) ? ceil(abs($_GET['page'])) : 1;

		switch ($this->person->object_name) {
			case 'Lead':
			case 'Contact':
				if (empty($this->person->email1) || trim($this->person->email1) == '') {
					return false;
				}
				return $this->freshdesk->getTicketsByEmail($this->person->email1,$this->filter,$this->page);
				break;

			case 'Account':
				return $this->freshdesk->getTicketsByCompanyName($this->person->name,$this->filter,$this->page);	
		}

		return null;
	}

	function constructFDTicketListLink($email='') {

		$email = null;
		switch ($this->person->object_name) {
			case 'Lead':
			case 'Contact':
				return ($this->utils->getSettings('ssl') ? "https://" : "http://" ). $this->utils->properDomain() . "/helpdesk/tickets/user_tickets?email=" . $this->person->email1;
				break;
			case 'Account':
				return ($this->utils->getSettings('ssl') ? "https://" : "http://" ). $this->utils->properDomain() . "/helpdesk/tickets/user_tickets?email=" . $this->person->name;
				break;
		}
	}

	function constructSettingsPageLink() {
		return "index.php?action=settings&module=freshdesk&from_object={$this->person->object_name}&from_rec={$this->person->id}";
	}
}