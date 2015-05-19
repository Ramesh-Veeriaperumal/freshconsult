<div id="fd_datacontainer">

  <a href="{$settings_link}" class="settings_link">Settings</a>
{if $response->errors->no_company }
  <p>
  <strong><em>{$object_name}</em> cannot be found in your helpdesk.</strong> <br /> <br />
  Please check if the company name given in Freshdesk exactly matches <em>{$object_name}</em>.
{elseif $response->errors->no_email }
  <p>
  <strong class="">No tickets associated with this {$object_type}</strong> <br /> <br /><br />
{else}
  {if $no_email_found }
    <p>
    <strong class="">This {$object_type} has no primary email associated.</strong> <br /> <br /><br />
  {else}
  <p>
    <strong class="error">Could not retrieve tickets information from Freshdesk servers. </strong> <br /> One of these steps might be able to solve the problem: <br /><br />
    <ul>
      <li>Please verify if the domain name is correct. <br />
          You have given <a href="{$url_prefix}" target="_new">{$domain_name}</a> as the domain name.<br />
          <em>Check your <a href="{$settings_link}">Freshdesk for SugarCRM configuration</a></em><br />
      </li>
      <li>Please verify the API Key. <br />
          If you are sure your domain name is correct, login into your Freshdesk account and to go your profile page, where you can find your API Key in the right sidebar. <br /><br />
      </li>
      <li>Please make sure your account is active. <br />
          If the above steps have been checked and verified, go to <a href="{$url_prefix}/account" target="_new">Freshdesk Account page</a> to check if your Freshdesk account is active (Paid Account/ Active trial).<br /><br />
      </li>
      <li>If you still can't retrieve ticket information, please contact our <a href="https://support.freshdesk.com" target="_new">Support</a>.
          <br /><br /> </li>
  {/if}
{/if}
</div>