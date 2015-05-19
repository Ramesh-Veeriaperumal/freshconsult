<form name="FreshdeskGeneralSettings" id="FreshdeskGeneralSettings" method="POST" action="">
	<input type="hidden" name="module" value="freshdesk">
	<input type="hidden" name="action" value="Admin">
	<input type="hidden" name="process" value="_freshdesk_save_settings" />

	<div class='add_table' style='margin-bottom:5px'>
		<table id="GlobalSearchSettings" class="GlobalSearchSettings edit view" style='margin-bottom:0px;' border="0" cellspacing="0" cellpadding="0">
		    <tr>
		    	<td align="right" width="35%">
		    		<label for="freshdesk_settings_domain">{$lbl_freshdesk_strings_domain} <span class="required">{$APP.LBL_REQUIRED_SYMBOL}</span> <label>
		    	</td>
				<td width='2%'>
					
				</td>
				<td width="63%">
					<input type="text" name="freshdesk[domain]" value="{$fd_settings_domain}" id="freshdesk_domain" /><br />
					<span class="helptext">{$lbl_freshdesk_strings_domain_helptext}</span>
					{if $fd_missing_setting_domain}
						<br /><span class="error">Please enter the domain name</span>
					{/if}
				</td>
			</tr>
			<tr>
				<td align="right" width="35%">
					<label>{$lbl_freshdesk_strings_ssl}</label>
				</td>
				<td> &nbsp; </td>
				<td width="63%">
					<input type="radio" {if $fd_settings_ssl}checked="checked"{/if} value="1"  name="freshdesk[ssl]" id="freshdesk_settings_ssl_yes" />
					<label for="freshdesk_settings_ssl_yes">Yes</label>
					<input type="radio" {if !$fd_settings_ssl}checked="checked"{/if} value="0" name="freshdesk[ssl]" id="freshdesk_settings_ssl_no" />
					<label for="freshdesk_settings_ssl_no">No</label> <br />
					<span class="helptext">{$lbl_freshdesk_strings_ssl_helptext}</span>
				</td>
			</tr>
			<tr>
				<td align="right" width="35%">
					<label for="freshdesk_setting_apikey">{$lbl_freshdesk_strings_apikey}  <span class="required">{$APP.LBL_REQUIRED_SYMBOL}</span> </label>
				</td>
				<td> &nbsp; </td>
				<td width="63%">
					<input type="text" value="{$fd_settings_apikey}"  name="freshdesk[apikey]" id="freshdesk_setting_apikey" /><br />
					<span class="helptext">{$lbl_freshdesk_strings_apikey_helptext}</span>
					{if $fd_missing_setting_apikey}
						<br /><span class="error">Please enter the API Key</span>
					{/if}
				</td>
			</tr>

		</table>
	</div>
	
	<table border="0" cellspacing="1" cellpadding="1">
		<tr>
			<td>
				<input type="hidden" name="redirect_module" value="{$redirect_module}" />
				<input type="hidden" name="redirect_action" value="{$redirect_action}" />
				<input type="hidden" name="redirect_record" value="{$redirect_record}" />
				<input title="{$APP.LBL_SAVE_BUTTON_LABEL}" class="button primary" type="submit" name="button" value="{$APP.LBL_SAVE_BUTTON_LABEL}">
			</td>
		</tr>
	</table>
</form>
