<?php

class FreshdeskUtils {
	var $settings;

	function FreshdeskUtils() {
		$this->settings = new Administration();
		$this->settings->retrieveSettings('freshdesk');
	}

	function getSettings($name) {
		return $this->settings->settings['freshdesk_' . $name ];
	}

	function properDomain($domain = '') {

		if ($domain == '') {
			$domain = $this->getSettings('domain');
		}

		$allowedSpecialDomains = array(
			'localhost',
			'localhost:3000',
		);
		if (!in_array($domain, $allowedSpecialDomains)) {
			$domain = strstr($domain,'.') ? $domain : $domain.'.freshdesk.com' ; //Adding .freshdesk.com if not given
		}

		return $domain;
	}



	function i18n($str) {
		global $app_list_strings;
		return $app_list_strings[$str];
	}

	function getStatusStr($status = 2 ) {
		$status = in_array($status, array(2,3,4,5)) ? $status : 2;
		return translate('LBL_FRESHDESK_STATUSES_'.$status);
	}

	function getPriorityStr($priority = 1 ) {
		$priority = in_array($priority, array(1,2,3,4)) ? $priority : 1;
		return translate('LBL_FRESHDESK_PRIORITIES_'.$priority);
	}

	function getSourceStr($source = 1 ) {
		$source = (in_array($source, array(1,2,3,4,5,6,7))) ? $source : 1;
		return translate('LBL_FRESHDESK_SOURCES_'.$source);
	}
}