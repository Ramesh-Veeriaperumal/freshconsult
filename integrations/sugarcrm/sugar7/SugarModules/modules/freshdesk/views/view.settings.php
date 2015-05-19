<?php
if(!defined('sugarEntry') || !sugarEntry) die('Not A Valid Entry Point');

require_once('include/MVC/View/SugarView.php');
require_once('modules/freshdesk/FreshdeskUtils.php');

class ViewSettings extends SugarView {

	function display() {

		$utils = new FreshdeskUtils();


	    $this->ss->assign("RETURN_MODULE", "Administration");
	    $this->ss->assign("RETURN_ACTION", "index");

	    //Labels and Helptexts in translated format
	    $this->ss->assign('lbl_freshdesk_strings_domain',translate('LBL_FRESHDESK_SETTINGS_GENERAL_DOMAIN','freshdesk'));
	    $this->ss->assign('lbl_freshdesk_strings_domain_helptext',translate('LBL_FRESHDESK_SETTINGS_GENERAL_DOMAIN_HELPTEXT','freshdesk'));
	    $this->ss->assign('lbl_freshdesk_strings_ssl',translate('LBL_FRESHDESK_SETTINGS_GENERAL_SSL','freshdesk'));
	    $this->ss->assign('lbl_freshdesk_strings_ssl_helptext',translate('LBL_FRESHDESK_SETTINGS_GENERAL_SSL_HELPTEXT','freshdesk'));
	    $this->ss->assign('lbl_freshdesk_strings_apikey',translate('LBL_FRESHDESK_SETTINGS_GENERAL_API_KEY','freshdesk'));
	    $this->ss->assign('lbl_freshdesk_strings_apikey_helptext',translate('LBL_FRESHDESK_SETTINGS_GENERAL_API_KEY_HELPTEXT','freshdesk'));

	    //Getting the settings
	    $this->ss->assign('fd_settings_domain',$utils->getSettings('domain'));
	    $this->ss->assign('fd_settings_ssl',$utils->getSettings('ssl'));
	    $this->ss->assign('fd_settings_apikey',$utils->getSettings('apikey'));


	    //Gettings the Redirect settings
	    $this->ss->assign('redirect_module', isset($_REQUEST['from_object']) ? $_REQUEST['from_object'] : 'Administration');
	    $this->ss->assign('redirect_action', isset($_REQUEST['from_object']) ? 'DetailView' : 'index');
	    $this->ss->assign('redirect_record', isset($_REQUEST['from_rec']) ? $_REQUEST['from_rec'] : '');

	    //Errors
	    if (isset($_GET['error_missing'])) {
	    	foreach ($_GET['error_missing'] as $name) {
	    		$this->ss->assign('fd_missing_setting_'.$name,true);
	    	}
	    }
		$this->ss->display('modules/freshdesk/tpls/settings_general.tpl');
	}
}