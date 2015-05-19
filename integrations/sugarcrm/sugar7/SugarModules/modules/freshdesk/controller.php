<?php
if(!defined('sugarEntry') || !sugarEntry) die('Not A Valid Entry Point');

class freshdeskController extends SugarController {

	protected function action_saveConfig() {
		$settings = new Administration();

		if ($_POST['process'] == '_freshdesk_save_settings') {

			$settings_data = array();
			$reqd_fields = array('domain','apikey');
			$missing_fields = array();
			if (isset($_POST['freshdesk']) && is_array($_POST['freshdesk']) && count($_POST['freshdesk'])) {
				foreach ($_POST['freshdesk'] as $name => $value) {
					$GLOBALS['log']->info("Freshdesk settings - " . print_r($_POST['freshdesk'],true));
					if (in_array($name, $reqd_fields) && (empty($value) || trim($value) == '')) {
						$missing_fields[] = $name;
					} else {
						$reqd_fields[$name] = $value;
					}
				}
			}


			if (count($missing_fields) == 0) {
				foreach ($reqd_fields as $name => $value) {
					$settings->save('freshdesk',$name,$value);
					$GLOBALS['log']->info("Updated Freshdesk settings");
				}
				$redirect_link = "index.php?module={$_POST['redirect_module']}&action={$_POST['redirect_action']}";
				if (isset($_POST['redirect_record']) && !empty($_POST['redirect_record'])) {
					$redirect_link .= "&record={$_POST['redirect_record']}";
				}
				SugarApplication::redirect($redirect_link);
			} else {
				$url_part = implode('&error_missing[]=', $missing_fields);
				$url_part .= "&module={$_POST['redirect_module']}&action={$_POST['redirect_action']}&record={$_POST['redirect_record']}";
				SugarApplication::redirect("index.php?module=freshdesk&action=settings&error_missing[]=".$url_part);
			}
		} else {
			print_r($_REQUEST);
		}
	}
}