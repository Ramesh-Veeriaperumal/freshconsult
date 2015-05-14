<?php
/**
 * @package Freshdesk Official
 * @version 1.6
 */
/*
Plugin Name: Freshdesk Official
Plugin URI: 
Description: Freshdesk Official is a seamless way to add your helpdesk account to your website. Supports various useful functions. 
Author: hjohnpaul,sathishfreshdesk,balakumars
Version: 1.6
Author URI: http://freshdesk.com/
*/


if ( ! defined( 'ABSPATH' ) ) die(); //Die if accessed directly.

#include freshdesk api class.
define('FD_PLUGIN_URL', plugin_dir_url( __FILE__ ));
require_once( plugin_dir_path( __FILE__ ) . 'freshdesk-plugin-api.php' );

add_action('init','fd_login'); //Sso handler and comment action handler
add_action( 'admin_menu', 'freshdesk_plugin_menu' ); //Plugin Menu
add_filter( 'comment_row_actions', 'freshdesk_comment_action', 10, 2 ); // This adds the comment action menu.
add_action( 'wp_ajax_fd_ticket_action', 'fd_action_callback' ); // This is the ajax action handler
add_filter('logout_url', 'fd_logout_url'); // For changing the logout url to point to Freshdesk.
add_filter('login_redirect', 'fd_login_redirect', 10, 3 ); // This is used to redirect to Freshdesk on SSO.

?>
<?php

function fd_login_redirect( $url, $request, $user ){
	$referrer_url = parse_url($_SERVER['HTTP_REFERER']);
	$query = parse_url($_SERVER['HTTP_REFERER'], PHP_URL_QUERY);
	parse_str($query, $params);
	$fd_redirect_to = $params['fd_redirect_to'];

	// For handling Redirect to Freshdesk on login.
	if ($fd_redirect_to && $_REQUEST['wp-submit'] == "Log In") {
		$user_name = $user->data->display_name;
		$freshdesk_options = get_option('freshdesk_options');
		$secret = $freshdesk_options['freshdesk_sso_key'];
		$data = $user_name.$user->data->user_email.time();
		$hash_key = hash_hmac("md5", $data, $secret);
		$ssl_url = $fd_redirect_to."/login/sso?name=".urlencode($user->data->display_name)."&email=".urlencode($user->data->user_email)."&timestamp=".time()."&hash=".urlencode($hash_key);
		sleep(1); // holding a bit so that it falls within FD 30 mins bar.
		header("Location: ".$ssl_url);
		die();
	}

	//For handling direct Wordpress login.
	if( $user && is_object( $user ) && is_a( $user, 'WP_User' ) ) {
		if( $user->has_cap( 'administrator' ) ) {
			$url = admin_url();
		} else {
			$url = home_url();
		}
	}
	return $url;
}

function fd_logout_url(){
	$freshdesk_options= get_option('freshdesk_options');
	$freshdesk_url = $freshdesk_options['freshdesk_domain_url'];
	if($_REQUEST['host_url']) {
		$freshdesk_url = get_domain_protocol()."://".$_REQUEST['host_url']; // case if it is a CNAME.
	}
	$fd_logout_url = $freshdesk_url."/logout";
	return $fd_logout_url;
}

function freshdesk_plugin_menu(){
	add_menu_page( 'Freshdesk Settings','Freshdesk','manage_options', 'freshdesk-menu-handle', 'freshdesk_settings_page');
	add_action('admin_init','freshdesk_settings_init');
}


function freshdesk_settings_page(){
?>
	<div class="wrap">
	<h2><?php echo __("Freshdesk Settings") ?></h2>
	<form class="form-table" method="post" action="options.php"> 
		
		<?php settings_fields('freshdesk_options_group'); //setting fields group?>
		<?php do_settings_sections('freshdesk-menu-handle'); ?>
  	<p class="submit"><input class="wp-core-ui button-primary" name="Submit" type="submit" value="<?php esc_attr_e('Save Changes'); ?>" /></p>
	</form>
	</div>
<?php
} //Function End

function freshdesk_settings_init(){
	register_setting( 'freshdesk_options_group', 'freshdesk_options', 'validate_freshdesk_settings');
	
	add_settings_section( 'freshdesk_settings_section','','', 'freshdesk-menu-handle');
	//Domain url and Sso Key.
	add_settings_field('freshdesk_domain_url', __('Helpdesk URL'), 'freshdesk_domain_callback' ,'freshdesk-menu-handle', 'freshdesk_settings_section');
	add_settings_field('freshdesk_sso_key', '', 'freshdesk_sso_callback' , 'freshdesk-menu-handle', 'freshdesk_settings_section');

	//Remote login and Logout Urls
	add_settings_field('freshdesk_remote_login','', 'freshdesk_sso_urls_callback' , 'freshdesk-menu-handle', 'freshdesk_settings_section');
	//Freshdesk Api Key.
	add_settings_field('freshdesk_api_key', 'API Key', 'freshdesk_api_callback' , 'freshdesk-menu-handle', 'freshdesk_settings_section');

	//Enable/disable freshdesk widget code.
	register_setting('freshdesk_options_group','freshdesk_feedback_options','validate_freshdesk_fb_settings');
	add_settings_field('freshdesk_enable_feedback', '', 'freshdesk_enable_fb_callback' , 'freshdesk-menu-handle', 'freshdesk_settings_section');
	add_settings_field('freshdesk_fb_widget_code', '', '' , 'freshdesk-menu-handle', 'freshdesk_settings_section');
}


// Callback Functions that constructs the UI.

function freshdesk_domain_callback(){
	$options = get_option('freshdesk_options');
	echo "<input class='fd_ui_element' id='freshdesk_domain_url' name='freshdesk_options[freshdesk_domain_url]' size='72' type='text' value='{$options['freshdesk_domain_url']}' />";
	echo '<div class="info-data fd_ui_element">Eg: https://yourcompany.freshdesk.com</div>';
}

function freshdesk_sso_callback(){
	$options = get_option('freshdesk_options');
	echo "<div class='freshdesk_sso_settings' style='display: none;' ><div class='info-title'>".__("SSO Shared Secret")."</div><input class='fd_ui_element' id='freshdesk_sso_key' name='freshdesk_options[freshdesk_sso_key]' size='72' type='text' value='{$options['freshdesk_sso_key']}' />";
	echo '<div class="info-data fd_ui_element freshdesk_helpdesk_url">Enable SSO on your Helpdesk account and copy the <a href="'.$options['freshdesk_domain_url'].'/admin/security" target="_blank" >SSO shared secret</a> above.</div></div>';
}

function freshdesk_sso_urls_callback(){
	$options = get_option('freshdesk_options');
	echo '<ul class="fd-content freshdesk_sso_settings" style="display: none;"><li><div class="info-title">'.__('Remote Login URL').'</div>';
	echo '<input class="fd-code" value="' . wp_login_url() . '?action=freshdesk-login" type="button"/>';
	echo '<div class="info-data freshdesk_helpdesk_url">'.__("Copy the above <i>Remote Login Url</i> to your").' <a href="'.$options['freshdesk_domain_url'].'/admin/security" target="_blank" >Single Sign On settings.</a></div></li>';
	echo '<li><div class="info-title">'.__('Remote Logout URL').'</div>';
	echo '<input class="fd-code" value="' . wp_login_url() . '?action=freshdesk-logout" type="button"/>';
	echo '<div class="info-data freshdesk_helpdesk_url" id="freshdesk_redirect_url">'.__("Copy the above <i>Remote Logout Url</i> to your").' <a href="'.$options['freshdesk_domain_url'].'/admin/security" target="_blank" >Single Sign On settings.</a></div></li></ul>';
}

function freshdesk_api_callback(){
	$options = get_option('freshdesk_options');
	echo "<input class='fd_ui_element' type='text' name='freshdesk_options[freshdesk_api_key]' size='72' value='{$options['freshdesk_api_key']}' />";
	echo '<div class="info-data fd_ui_element">'.__("Your Helpdesk's Apikey will be available under Agent profile settings.").'</div>';

}

function freshdesk_enable_fb_callback(){
	$options = get_option('freshdesk_feedback_options');
	echo '<tr><td colspan="2"><ul class="fd-form-table"><li><div><label><input class="fd_button" type="checkbox" name="freshdesk_feedback_options[freshdesk_enable_feedback]" id="freshdesk_enable_feedback" '.$options['freshdesk_enable_feedback'].' /><span class="fd_ui_element fd-bold">Show FeedBack Widget </span></label><div><div class="info-data fd_lmargin">This widget will be shown on your wordpress site for Visitors to post feedback</div></li>';
	freshdesk_fb_widget_callback();
}

function freshdesk_fb_widget_callback(){
	$options = get_option('freshdesk_feedback_options');
	echo '<li><div id="freshdesk_feedback_widget_id" style="display: none;"><div class="info-data  fd_text fd_ui_element freshdesk_widget_url"><a href="'.$options['freshdesk_domain_url'].'/admin/widget_config" target="_blank">Copy feedback widget code</a> from your helpdesk and paste it below.</div>';
	echo '<textarea class="fd_ui_element fd_text" name="freshdesk_feedback_options[freshdesk_fb_widget_code]" id="freshdesk_fb_widget_code" rows="7">'.$options['freshdesk_fb_widget_code'].'</textarea></div></li></ul></td></tr>';
}

/* This is the validation(db before_save) callback */
function validate_freshdesk_settings($input){
	$url=trim($input['freshdesk_domain_url']);
	if (!preg_match("/\b(?:(?:https?):\/\/|www\.)[-a-z0-9+&@#\/%?=~_|!:,.;]*[-a-z0-9+&@#\/%=~_|]/i", $url)) {
  	$url ='';
	}
	$sso_secret = $input['freshdesk_sso_key'];
	$api_key = $input['freshdesk_api_key'];
	$enable_feedback = validate_checkbox($input['freshdesk_enable_feedback']);

	$settings = array('freshdesk_domain_url'=> $url,'freshdesk_sso_key'=>$sso_secret,'freshdesk_api_key'=>$api_key,'freshdesk_enable_feedback'=> $enable_feedback);

	return $settings;	
}

function validate_freshdesk_fb_settings($input){
	$enable_feedback = validate_checkbox($input['freshdesk_enable_feedback']);
	$fb_widget_code = $input['freshdesk_fb_widget_code'];
	$settings = array('freshdesk_fb_widget_code'=>$fb_widget_code,'freshdesk_enable_feedback'=> $enable_feedback);
	return $settings;
}

function validate_checkbox($input){
	if($input == 'on'){
		$input = 'checked';
	}
  return $input;
}
/* Validation callback End. */


/* Adding 'Create Ticket' Action for the Comments*/
 function freshdesk_comment_action( $actions, $comment ) {
 	$options = get_option('freshdesk_options');
    if (current_user_can( 'administrator') ){
      if((trim(get_comment_meta($comment->comment_ID,"fd_ticket_id", true)) == false)){
      	$actions['freshdesk'] = '<a class="fd_convert_ticket" href="#" domain_url='.$options['freshdesk_domain_url'].' id="' . $comment->comment_ID . '">' . __( 'Convert to Ticket', 'fd_ticket' ) . '</a>';
      }
      else{
      	$actions['freshdesk'] = '<a class="fd_convert_ticket" href="#" title="hello" ticket_id="'.get_comment_meta($comment->comment_ID,"fd_ticket_id", true).'"domain_url='.$options['freshdesk_domain_url'].' id="' . $comment->comment_ID . '">' . __( 'View Ticket', 'fd_ticket_link' ) . '</a>';
      }
    }
    return $actions;
  }


//freshdesk login sso handler/feedback widget handler.
//and css/js loader for settings and comments page.
function fd_login(){
 	global $pagenow, $display_name , $user_email;
 	if ( 'wp-login.php' == $pagenow ){
 		if ($_GET['action'] == 'freshdesk-login' ) {
 			// NOTE: is_user_logged_in dont't work during  [wp-submit] => Log In
		 	if ( is_user_logged_in() ){
			// For the case when user has already logged into Wordpress and then in another tab opens Freshdesk and click on login then he should be logged into FD with out entering credentials.
		      $current_user = wp_get_current_user();
		      $freshdesk_options= get_option('freshdesk_options');
		      $secret = $freshdesk_options['freshdesk_sso_key'];
		      $user_name= $current_user->user_firstname.$current_user->user_lastname;
		      $user_email = $current_user->user_email;
          $data = $user_name.$user_email.time();
		      $hash_key = hash_hmac("md5",$data,$secret);
		      $url = freshdesk_sso_login_url($user_name,$user_email,$hash_key);
					header( 'Location: '.$url ) ;	
			  die();
			}
		 	else{ // if wordpress is not logged in.
		 		$freshdesk_options= get_option('freshdesk_options');
		    $domain = ($_REQUEST['host_url']) ? get_domain_protocol()."://".$_REQUEST['host_url'] : $freshdesk_options['freshdesk_domain_url']; // Redirect to the host url if host url option is present with the request.
		    if (isset($domain)){
		 			header("Location: " .wp_login_url()."?fd_redirect_to=".$domain);
	 				die();
		 		}
	 		}
		}
		if ($_GET['action'] == 'freshdesk-logout' ) {
			$redirect_url = wp_login_url();
			// Sometimes we get the http referer and some times don't so to find if it is coming from Freshdesk we do a two condition check and if one is satisfied then Freshdesk is the referer.
			// Condition-1) Host url is a substring of http referer
			// Condition-2) Host url exists and the http_referer is empty because request from within wordpress seems to always have a referer.
			$condition_one = (strpos($_SERVER['HTTP_REFERER'], $_REQUEST['host_url']) !== FALSE) ? TRUE : FALSE;
			$condition_two = ($_REQUEST['host_url'] && empty($_SERVER['HTTP_REFERER']));
			if ($condition_one || $condition_two) {
				$redirect_url = $redirect_url."?fd_redirect_to=".get_domain_protocol()."://".$_REQUEST['host_url'];
			}
			wp_logout();
			header('Location: '.$redirect_url);
			die();
		}
 	}
 	if('edit-comments.php' == $pagenow ||  ($_GET['page'] == 'freshdesk-menu-handle')){
 		if (current_user_can( 'manage_options' )) {
		 		wp_enqueue_script('fd_plugin_js',FD_PLUGIN_URL . 'js/freshdesk_plugin_js.js',array('jquery'));
		 		wp_localize_script( 'fd_plugin_js', 'myAjax', array( 'ajaxurl' => admin_url( 'admin-ajax.php' )));
 			}
 	}
	wp_enqueue_style('fd_plugin_css',FD_PLUGIN_URL . 'css/freshdesk_plugin.css');
	$feedback_options=get_option('freshdesk_feedback_options');
	if ($feedback_options['freshdesk_enable_feedback'] == "checked"){
  	add_action( 'wp_footer','freshdesk_widget_code');
  }
}

	//Feedback widget code snippet include.
	function freshdesk_widget_code() {
    $options = get_option('freshdesk_feedback_options');
    echo $options['freshdesk_fb_widget_code'];
  }

  function freshdesk_handshake_secret(){

  }

	function get_domain_protocol() {
		$freshdesk_options= get_option('freshdesk_options');
		$domain_url = $freshdesk_options['freshdesk_domain_url'];
		$temp_array = explode(":",$domain_url);
		$protocol = $temp_array[0];
		return $protocol;
	}

  function freshdesk_sso_login_url($user_name,$email,$hash_key){
	$host_url = $_GET['host_url'];
	$protocol = get_domain_protocol()."://";
	$domain = (empty($host_url) === true) ? $domain_url : $host_url; // Take the domain_url if host_url is null.
	return $protocol.$domain."/login/sso?name=".urlencode($user_name)."&email=".urlencode($email)."&timestamp=".time()."&hash=".urlencode($hash_key);
  }

  //Ajax Action handler. Freshdesk Ticket creation handled here.
	function fd_action_callback() {
		$id = $_POST['commentId'];

		$comment = get_comment($id);
		$comment_link = get_comment_link($comment,'all');
		// echo "comment:".$id;
		$email = $comment->comment_author_email;
		$description = $comment->comment_content;
		$description = $description . "<br/><br/><a href=" . htmlentities($comment_link) . ">Go to comment</a>";
		$type = $comment->comment_type;
		$comment_meta = $comment->comment_agent;
		$comment_date = $comment->comment_date;
		$comment_post = $comment->comment_post_ID;
		$comment_author_name = $comment->comment_author;
		$subject = "comment id :".$id;
		//die("DONE..".$whatever); // this is required to return a proper result

		$options = get_option('freshdesk_options');
		$fd_api_handle = new Freshdesk_Plugin_Api($options['freshdesk_api_key'],$options['freshdesk_domain_url']);
		$result = $fd_api_handle->create_ticket($email,$subject,$description);
			$response = array(
	   		'what'=>'helpdesk_ticket',
		  	'action'=>'create',
		    'id'=>'1',
		    'data'=>$result
			);
			// echo $fd_api_handle->get_response();
			$resp = add_comment_meta($id, 'fd_ticket_id', $result, false);
			$xmlResponse = new WP_Ajax_Response($response);
			$xmlResponse->send();

	}


//plugin settings page end.
?>