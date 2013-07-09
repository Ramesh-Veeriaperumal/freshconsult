var I18n = I18n || {};
I18n.translations = {"cs":{"integrations":{"icontact":{"desc":"Export customer information, manage existing subscriptions, and bring in insights on customer usage statistics right inside Freshdesk.","helptext":"<h4>iContact Integration Help</h4><br/> To integrate with iContact, go to <a target='_blank' href='https://app.icontact.com/icp/core/externallogin'>https://app.icontact.com/icp/core/externallogin</a> and grant access to the Freshdesk app by entering the below Application ID <br/><br/><b>qB7RYQgliAPwl5dwezYF0kAN4Islhj4e</b><br/><br/> Set a password of your choice and click &quot;Save&quot;. This API password will be used for all API requests from Freshdesk. <br/><br/> Copy the API URL from the &quot;Account Information&quot; section and paste it in the API URL field here. Enter your iContact username and the new API password and click Update. ","label":"iContact","form":{"api_url_info":"To get your API URL, go to https://app.icontact.com/icp/core/externallogin and copy the API URL from &quot;Account Information&quot; section. ","username":"Jm\u00e9no u\u017eivatele iContact","app_id":"Id Aplikace","api_url":"URL pro API","api_password":"Heslo pro API"}},"capsule_crm":{"helptext":"<h4>Zp\u011btn\u00fd odkaz z aplikace Capsule do aplikace Freshdesk</h4><p><br/>M\u016f\u017eete vytvo\u0159it odkaz v aplikaci Capsule CRM tak, aby se l\u00edstky kontakt\u016f zobrazily v aplikaci Freshdesk.</p> <p>Sta\u010d\u00ed p\u0159ej\u00edt do <br /><b>Nastaven\u00ed -> Vlastn\u00ed pole -> Pro lidi a organizaci</b></p><p> Pot\u00e9 klikn\u011bte na polo\u017eku \u201eP\u0159idat nov\u00fd...\u201c a zvolte polo\u017eku <b>Generovan\u00fd odkaz</b></p> <p>Zkop\u00edrujte identifik\u00e1tor URI p\u0159esn\u011b dle zn\u00e1zorn\u011bn\u00ed n\u00ed\u017ee a vlo\u017ete jej do aplikace Capsule CRM jako definici odkazu<span class=\"info-code\">http://%{full_domain}/helpdesk/tickets?email={email}</span></p>","label":"Schr\u00e1nka CRM"},"jira_settings":{"update_jira_status":"Aktualizovat stav aplikace JIRA","info3":"Kdy\u017e je na FreshDesku p\u0159id\u00e1n koment\u00e1\u0159 ","add_private_note_in_fd":"P\u0159idat soukromou pozn\u00e1mku v aplikaci Freshdesk a upozornit z\u00e1stupce.","info2":"Kdy\u017e je stav po\u017eadavku aktualizov\u00e1n ve FreshDesku ","update_status_in_fd":"Aktualizovat stav v aplikaci Freshdesk.","info1":"Kdy\u017e je po\u017eadavek na Freshdesku spojen s probl\u00e9mem v JIRA, prove\u010f tyto akce.","send_reply_in_fd":"Upozornit z\u00e1kazn\u00edka e-mailem.","add_public_note_in_fd":"P\u0159idat ve\u0159ejnou pozn\u00e1mku v aplikaci Freshdesk.","info5":"Jakmile je p\u0159id\u00e1n koment\u00e1\u0159 v aplikaci JIRA","add_comment_in_jira":"P\u0159idat koment\u00e1\u0159 v aplikaci JIRA","sync_updates":"Synchronizovat zm\u011bny","info4":"Jakmile je stav probl\u00e9mu aktualizov\u00e1n v aplikaci JIRA","none":"Neud\u011blat nic."},"logmein":{"desc":"Poskytn\u011bte sv\u00fdm z\u00e1kazn\u00edk\u016fm a zam\u011bstnanc\u016fm okam\u017eitou vzd\u00e1lenou podporu s aplikac\u00ed LogMeIn Rescue","helptext":"<h4>N\u00e1pov\u011bda k integraci aplikace LogMeIn Rescue</h4><p><br/> Chcete-li integrovat aplikaci LogMeIn Rescue do aplikace Freshdesk, zadejte identifik\u00e1tor sv\u00e9 spole\u010dnosti pro aplikaci LogMeIn Rescue a heslo SSO a klikn\u011bte na polo\u017eku Aktualizovat. <br/>Jakmile bude pom\u016fcka aplikace LogMeIn Rescue povolena, bude ji mo\u017en\u00e9 naj\u00edt na str\u00e1nce s \u00fadaji o l\u00edstku. <br/><br/>Ke spu\u0161t\u011bn\u00ed konzoly pro techniky p\u0159\u00edmo z pom\u016fcky aplikace Freshdesk pou\u017eijte polo\u017eku  &quot;Spustit konzolu pro techniky&quot;. <br/>Pot\u00e9 m\u016f\u017eete vygenerovat k\u00f3d PIN a sd\u011blit \u017eadateli pokyny, abyste mohli i nad\u00e1le poskytovat podporu v aplikaci LogMeIn Rescue. <br/><br/> <b>Pozn\u00e1mka:</b> E-mail z\u00e1stupce by m\u011bl odpov\u00eddat identifik\u00e1toru SSO technika aplikace LogMeIn Rescue. Chcete-li nastavit sv\u016fj identifik\u00e1tor SSO, p\u0159ejd\u011bte do Administrativn\u00ed st\u0159edisko -> Jm\u00e9no technika -> Organizace -> SSOID","note":{"session_id":"ID relace","tech_notes":"Pozn\u00e1mky technika","platform":"Platforma koncov\u00e9ho u\u017eivatele","chatlog":"Protokol konverzace","header":"Va\u0161e \u00fadaje o relaci v aplikaci LogMeIn Rescue","work_time":"Celkov\u00e1 pracovn\u00ed doba (v sekund\u00e1ch)","tech_email":"E-mail technika","tech_name":"Jm\u00e9no technika"},"label":"LogMeIn Rescue","form":{"company_id":"Identifik\u00e1tor spole\u010dnosti","logmein_sso_pwd_info":"Chcete-li nastavit sv\u00e9 heslo SSO, p\u0159ejd\u011bte do Administrativn\u00ed st\u0159edisko -> Skupina technik\u016f -> Glob\u00e1ln\u00ed nastaven\u00ed -> Jednotn\u00e9 p\u0159ihla\u0161ov\u00e1n\u00ed -> Nov\u00e9 heslo SSO","password":"Heslo SSO","widget_title":"N\u00e1zev pom\u016fcky","logmein_company_info":"Chcete-li z\u00edskat identifik\u00e1tor sv\u00e9 spole\u010dnosti, p\u0159ejd\u011bte do Administrativn\u00ed st\u0159edisko -> Skupina technik\u016f -> Glob\u00e1ln\u00ed nastaven\u00ed -> P\u0159\u00edklad ASP.Net C# na stran\u011b serveru"}},"freshbooks":{"desc":"\u010cas str\u00e1ven\u00fd na ud\u00e1lostech m\u016f\u017eete protokolovat do sv\u00fdch projekt\u016f a \u00fakol\u016f Freshbooks.","helptext":"<h4>N\u00e1pov\u011bda integrace Freshbooks</h4><p><br/>K integraci Freshbooks s Freshdeskem nejprve pot\u0159ebujete z\u00edskat API Freshbooks a ov\u011b\u0159ovac\u00ed token. <br/><br/>P\u0159ihlaste se ke sv\u00e9mu \u00fa\u010dtu Freshbooks, klikn\u011bte na <b>kartu Lid\u00e9</b> a pokra\u010dujte na <b>Zam\u011bstnanci a dodavatel\u00e9</b>. Klikn\u011bte na <b>Upravit</b> ve sv\u00e9 spr\u00e1v\u011b.  Zde najdete URL API a ov\u011b\u0159ovac\u00ed token.<br/><br/>Ve Freshdesku klepn\u011bte na ud\u00e1lost (l\u00edstek) a p\u0159ejd\u011bte na kartu \u010dasov\u00e9ho listu.  Pak m\u016f\u017eete do Freshbooks p\u0159idat svou polo\u017eku sledov\u00e1n\u00ed \u010dasu.","label":"Freshbooks","form":{"freshbooks_note":"Text pozn\u00e1mek","api_url_info":"Zadejte \u00fapln\u00e9 URL API v\u010detn\u011b https. Nap\u0159.: https://example.freshbooks.com/api/2.1/xml-in","api_key_info":"&quot;&quot;","api_key":"Ov\u011b\u0159ovac\u00ed token","widget_title":"N\u00e1zev panelu","api_url":"URL API","freshbooks_note_info":"Tento text se p\u0159ipoj\u00ed na konec pozn\u00e1mky, spole\u010dn\u011b se str\u00e1ven\u00fdm \u010dasem."}},"campaignmonitor":{"desc":"Look up and manage subscriptions on your Campaign Monitor account, and bring in insights on customer usage statistics right inside Freshdesk. ","helptext":"<h4>Campaign Monitor Integration Help</h4><br/>To integrate with Campaign Monitor, you should input your API Key and ClientID from Campaign Monitor. <br/></br/> API Key can be obtained from Campaign Monitor's Account Settings.<br/><br/> The instructions to get your ClientID are available from <a target='_blank' href='http://www.campaignmonitor.com/api/getting-started/#clientid'> http://www.campaignmonitor.com/api/getting-started/#clientid </a> . <br/><br/>Now click &quot;Update&quot; to get started with your Campaign Monitor integration.","label":"Campaign Monitor","form":{"api_key_info":"Kl\u00ed\u010d API z\u00edsk\u00e1te v nastaven\u00ed \u00fa\u010dtu","client_id_info":"To get your Client ID, follow the instructions given in http://www.campaignmonitor.com/api/getting-started/#clientid","api_key":"Kl\u00ed\u010d API","client_id":"ID klienta"}},"dropbox":{"desc":"P\u0159ipoj a sd\u00edlej sv\u00e1 data a soubory z DropBoxu.","helptext":"<h4>N\u00e1pov\u011bda pro integraci s DropBoxem</h4><br/><p>Integrace s DropBoxem umo\u017e\u0148uje z\u00e1stupc\u016fm a u\u017eivatel\u016fm hledat soubory na DropBox adres\u00e1\u0159\u00edch a s\u00edlet je kdy\u017e odes\u00edlaj\u00ed po\u017eadavky na FreshDesk. U po\u017eadavku je m\u00edsto p\u0159ilo\u017een\u00e9ho souboru pouze odkaz na DropBox, co\u017e sni\u017euje n\u00e1roky na velikost mailu.</p><p>P\u0159ed nastaven\u00edm integrace jd\u011bte na str\u00e1nky <strong><a href='https://www.dropbox.com/developers/apps' target='_blank' alt='developers'>DropBox Developers</a></strong>. </p><p>1. Na nastaven\u00ed My Apps klikn\u011bte na 'Create an App'.</p><p>@. Zvolte typ aplikace 'Chooser'. </p><p>3. Zadejte jm\u00e9no a popis.</p><p>4. Do dom\u00e9ny zadejte URL sv\u00e9ho helpdesku.<i>(nap\u0159. com.freshdesk.com)</i></p><p>5. Klikn\u011btena tla\u010d\u00edtko Create.</p><p>A nakonec zkop\u00edrujte Application key nov\u00e9 aplikace na tuto str\u00e1nku a ulo\u017ete zm\u011bny. V\u00e1\u0161 DropBox Chooser by m\u011bl nyn\u00ed b\u00fdt hotov. M\u016f\u017eete jej vyzkou\u0161et na formul\u00e1\u0159i Nov\u00fd po\u017eadavek.</p>","label":"DropBox","form":{"app_key":"Registrovan\u00e9 Application key pro va\u0161i dom\u00e9nu","app_key_info":"Vytvo\u0159te aplikaci v DropBoxu a uve\u010fte zde Application key."}},"batchbook":{"desc":"P\u0159eneste sv\u00e9 informace o kontaktech z va\u0161eho Batchbooku do Freshdesku","helptext":"<h4>Batchbook Integration</h4><p><br>Link your Batchbook account with Freshdesk to display contact information on the Contacts and Tickets pages. Please specify your domain and API key in this page to configure the integration. <br><br>Freshdesk pulls in the Name, Title, Company Name, Contact Address, Phone Number &amp; Mobile Numbers from Batchbook and makes it available for your agents.<br><br>You can lookup contacts from Batchbook by searching with their email address. If multiple contacts exist with the same address, all of them will be displayed in the form of a list.</p><br/> ","detect_error":"Nelze detekovat verzi Batchbooku. Pros\u00edm, zkontrolujte dom\u00e9nu.","label":"Batchbook","form":{"version":{"auto_detect":"Detekovat automaticky","classic":"Klasick\u00fd","label":"Verze","new":"Nov\u00fd"},"version_info":"Ppole Verze v\u00e1m umo\u017en\u00ed zvolit mezi <i>Batchbook klasick\u00fd</i> a <i>Batchbook Nov\u00fd</i>.","domain_info":"Nap\u0159. pokud je URL va\u0161eho Batchbooku <strong>http:/mycompany.batchbook.com/</strong>, vlo\u017ete <strong>mycompany</strong>.</span>","api_key_info":"V\u00e1\u0161 kl\u00ed\u010d API pro Batchbook naleznete ve va\u0161em <i>Batchbook \u00fa\u010dtu</i>.","api_key":"Kl\u00ed\u010d API","widget_title":"N\u00e1zev Propojen\u00ed","domain":"Dom\u00e9na Batchbook:"}},"nimble":{"desc":"Ve Freshdeku budou dostupn\u00e9 kontaktn\u00ed informace z CRM syst\u00e9mu Nimble.","label":"Nimble"},"jira":{"desc":"P\u0159ev\u00e9st l\u00edstky na pot\u00ed\u017ee, kter\u00e9 lze sledovat v JIRA.","helptext":"<h4>JIRA Integration Help</h4><p><br/>To integrate JIRA with Freshdesk, enter your JIRA administrator username and password. The integration supports both on-demand and on-premise variants, from JIRA 4.2 upto the latest version - JIRA 5.<br/><br/> To create an issue or link to an existing issue from Freshdesk, navigate to the Tickets page and click on <img src='/images/ticket-icon/jira.png'/><br/><br/> To view details of your linked Freshdesk tickets in JIRA, and conversely to view JIRA issue details in Freshdesk, the JIRA administrator is recommended to create a Free Text custom field with the name &quot;Freshdesk Tickets&quot; as described below. <br/><br/>Log on to your JIRA account, click on <b>Administration</b>, navigate to <b>Issues</b> -> <b>Fields</b> and click on <b>Add Custom Field</b>. In <b>Create Custom Field</b> screen, select <b> Free Text Field </b> and click on <b>Next</b>. Input <b>&quot;Freshdesk Tickets&quot;</b> in Field Name and click on Finish. In <b>Associate field to Screens</b> page, select all the check-boxes and click on 'Update'.<br/><br/>","label":"Atlassian JIRA","form":{"add_note":"P\u0159idat to jako soukromou pozn\u00e1mku.","update_jira_status":"Aktualizovat tak\u00e9 stav aplikace JIRA.","fd_comment_sync":"Pro libovoln\u00fd koment\u00e1\u0159 p\u0159idan\u00fd v aplikaci Freshdesk %{dropdown}","jira_comment_sync":"Pro libovoln\u00fd koment\u00e1\u0159 p\u0159idan\u00fd k probl\u00e9mu v aplikaci JIRA %{dropdown}","send_reply":"Zaslat to jako odpov\u011b\u010f z\u00e1kazn\u00edkovi.","add_jira_comment":"P\u0159idat to jako koment\u00e1\u0159 v aplikaci JIRA.","domain_info":"Zadejte \u00faplnou adresu URL \u00fa\u010dtu JIRA v\u010detn\u011b https/http. nap\u0159. https://example.atlassian.net. <br /><span class='italics'>Pozn\u00e1mka: Lok\u00e1ln\u011b instalovan\u00e9 verze JIRA by m\u011bly b\u00fdt p\u0159\u00edstupn\u00e9 z Internetu. </span>","jira_note_info":"Tento text se p\u0159id\u00e1 do popisu pot\u00ed\u017ee v JIRA.","jira_status_sync_update_customer":"Odeslat odpov\u011b\u010f z\u00e1kazn\u00edkovi a aktualizovat pole stavu.","username":"U\u017eivatelsk\u00e9 jm\u00e9no","jira_note":"Popisuj\u00edc\u00ed text","password":"Heslo","jira_status_sync":"Pro libovolnou zm\u011bnu ve stavu probl\u00e9mu v aplikaci JIRA %{dropdown}","widget_title":"N\u00e1zev widgetu","do_nothing":"Neud\u011blat nic.","fd_status_sync":"Pro libovolnou zm\u011bnu ve stavu aplikace Freshdesk %{dropdown}","jira_status_sync_update_field":"Aktualizovat pole stavu aplikace Freshdesk.","domain":"Dom\u00e9na"}},"custom_application":{"desc":"M\u016f\u017eete p\u0159idat vlastn\u00ed pom\u016fcku, a zobrazit tak libovoln\u00fd \u00fadaj pomoc\u00ed vlastn\u00edho skriptu.","description":"Popis","script":"Skript","small_help_text":"M\u016f\u017eete vyvinout vlastn\u00ed pom\u016fcku pomoc\u00ed jazyk\u016f html, css a javascript.","helptext":"<h4>N\u00e1pov\u011bda k vlastn\u00ed pom\u016fcce</h4><p><br/> M\u016f\u017eete vyvinout vlastn\u00ed pom\u016fcku pomoc\u00ed jazyk\u016f html, css a javascript.</br></br>Chcete-li vytvo\u0159it vlastn\u00ed pom\u016fcku, zadejte n\u00e1zev sv\u00e9 pom\u016fcky a kr\u00e1tce ji popi\u0161te.</br>Sv\u016fj k\u00f3d zadejte do pole \u201eSkript\u201c. V\u00edce informac\u00ed o skriptu najdete na na\u0161\u00ed str\u00e1nce s \u0159e\u0161en\u00edmi.</br></br>Kliknut\u00edm na polo\u017eku <b>Zobrazit n\u00e1hled</b> m\u016f\u017eete zobrazit budouc\u00ed podobu sv\u00e9 pom\u016fcky na str\u00e1nk\u00e1ch kontakt\u016f i l\u00edstk\u016f.","edit":"Upravit vlastn\u00ed pom\u016fcku","label":"Vlastn\u00ed pom\u016fcka","name":"N\u00e1zev","form":{"create_n_enable":"Vytvo\u0159it a povolit","widget_script":"Fragment k\u00f3du pom\u016fcky","widget_title":"N\u00e1zev pom\u016fcky","insert_placeholder":"Vlo\u017eit z\u00e1stupn\u00fd symbol"},"new":"Nov\u00e1 vlastn\u00ed pom\u016fcka"},"highrise":{"desc":"P\u0159i \u0159e\u0161en\u00ed po\u017eadavk\u016f ve Freshdesku si m\u016f\u017eete prohl\u00ed\u017eet informace o osob\u00e1ch z CRM syst\u00e9mu Highrise.","helptext":"<h4>Propojen\u00ed na Highrise</h4><p><br>Pro zobrazen\u00ed kontaktn\u00edch informac\u00ed vlo\u017ete svou dom\u00e9nu a API kl\u00ed\u010d. Po konfiguraci bude toto Propojen\u00ed zobrazeno na z\u00e1lo\u017ek\u00e1ch Osob a Po\u017eadavk\u016f.<br><br>Z CRM syst\u00e9mu Highrise se zde bude zobrazovat Jm\u00e9no, Pozice, Spole\u010dnost, Adresa, Telefon a Mobil<br><br>Prohled\u00e1n\u00ed dat v Highrise CRM bude na z\u00e1klad\u011b emalov\u00e9 adresy; v\u00fdsledky budou zobrazeny formou seznamu.</p>","label":"Highrise","form":{"domain_info":"Nap\u0159. pokud je URL va\u0161eho Highrise <strong>http://mycompany.higrisehq.com/</strong>, pak zadejte <strong>mycompany</strong>.</span>","api_key_info":"V\u00e1\u0161 API kl\u00ed\u010d pro Highrise naleznete v Highrise aplikaci. Pros\u00edme zkop\u00edrujte jej sem.","api_key":"Kl\u00ed\u010d API","widget_title":"N\u00e1zev Dopl\u0148ku","domain":"Dom\u00e9na Highrise:"}},"add_new_freshplug":"P\u0159idat nov\u00fd FreshPlug","capsule":{"desc":"Informace o kontaktu si m\u016f\u017eete zobrazit ze schr\u00e1nky CRM v aplikaci Freshdesk. K t\u011bmto informac\u00edm lze p\u0159istupovat na str\u00e1nce podrobnost\u00ed o ud\u00e1losti a na str\u00e1nce podrobnost\u00ed o kontaktu.","label":"Schr\u00e1nka CRM","form":{"bcc_drop_box_mail":"Po\u0161tovn\u00ed adresa dropboxu","bcc_drop_box_mail_info":"Svou jedine\u010dnou e-mailovou adresu schr\u00e1nky dropboxu najdete pod <b>\u201cNastaven\u00ed -> Po\u0161tovn\u00ed dropbox\u201d</b>.<br /> (To najdete v prav\u00e9m horn\u00edm rohu str\u00e1nky.)<br /> E-mailovou adresu zkop\u00edrujte a vlo\u017ete ji do textov\u00e9ho pol\u00ed\u010dka naho\u0159e. <br /> Freshdesk automaticky p\u0159id\u00e1 tuto e-mailovou adresu do pole skryt\u00fdch p\u0159\u00edjemc\u016f, kdy\u017e budete odpov\u00eddat na n\u011bjak\u00fd l\u00edstek","domain_info":"Zadejte jen samotnou dom\u00e9nu, bez https. Nap\u0159.: example.capsulecrm.com","api_key_info":"Abyste z\u00edskali sv\u016fj jedine\u010dn\u00fd kl\u00ed\u010d API, p\u0159ihlaste se ke sv\u00e9mu \u00fa\u010dtu schr\u00e1nky CRM a p\u0159ejd\u011bte na <br /> <b>\u201cU\u017eivatel -> Moje nastaven\u00ed\u201d</b>. (To najdete v prav\u00e9m horn\u00edm rohu str\u00e1nky.)<br /> Jedine\u010dn\u00fd kl\u00ed\u010d API z\u00edsk\u00e1te kliknut\u00edm na <b>\u201cToken ov\u011b\u0159en\u00ed API\u201d</b>.<br /> Kl\u00ed\u010d zkop\u00edrujte a vlo\u017ete jej do textov\u00e9ho pol\u00ed\u010dka naho\u0159e.","api_key":"Kl\u00ed\u010d API","widget_title":"N\u00e1zev widgetu","domain":"Dom\u00e9na"}},"sugarcrm":{"desc":"Informace o kontaktu si m\u016f\u017eete zobrazit ze SugarCRM ve Freshdesku.","helptext":"<h4>N\u00e1pov\u011bda k integraci aplikace Sugar CRM</h4><p><br/> Na str\u00e1nk\u00e1ch s kontakty a l\u00edstkem aplikace Freshdesk m\u016f\u017eete p\u0159istupovat ke kontaktn\u00edm \u00fadaj\u016fm aplikace SugarCRM. <br /><br /> Budou p\u0159\u00edstupn\u00e9 n\u00e1sleduj\u00edc\u00ed datov\u00e9 body \u2013 jm\u00e9no, titul, spole\u010dnost, odd\u011blen\u00ed, kontaktn\u00ed adresa, telefon a mobiln\u00ed \u010d\u00edsla. <br /><br />Funkce vyhled\u00e1v\u00e1n\u00ed je zalo\u017eena na e-mailov\u00e9 adrese. Pokud bude v\u00edce kontakt\u016f se stejnou e-mailovou adresou, v\u0161echny budou zobrazeny v seznamu.","label":"SugarCRM","form":{"domain_info":"Je-li nap\u0159. va\u0161\u00ed adresou SugarCRM <strong>http://mycompany.xyz/sugar/index.php?module=Administration&action=index</strong> , zadejte <strong> http://mycompany.xyz/sugar </strong><br /><br /> Pozn\u00e1mka: Lok\u00e1ln\u011b instalovan\u00e9 verze SugarCRM by m\u011bly b\u00fdt p\u0159ipojen\u00e9 k Internetu. </span>","username":"U\u017eivatelsk\u00e9 jm\u00e9no","password":"Heslo","widget_title":"N\u00e1zev widgetu","domain":"URL \u00fa\u010dtu SugarCRM"}},"harvest":{"desc":"\u010cas str\u00e1ven\u00fd na ud\u00e1lostech m\u016f\u017eete protokolovat do sv\u00fdch projekt\u016f a \u00fakol\u016f Harvest.","helptext":"<h4>N\u00e1pov\u011bda integrace Harvest</h4><p><br/>Chcete-li integrovat Harvest s Freshdeskem, zadejte sv\u016fj <b>n\u00e1zev dom\u00e9ny</b> a klikn\u011bte na Aktivovat.<br/><br/>Klikn\u011bte na ud\u00e1lost, p\u0159ejd\u011bte na <b>kartu \u010dasov\u00e9ho listu</b>.  pak se m\u016f\u017eete p\u0159ihl\u00e1sit zad\u00e1n\u00edm sv\u00e9ho <b>u\u017eivatelsk\u00e9ho jm\u00e9na</b> a <b>hesla</b> syst\u00e9mu Harvest. Nyn\u00ed m\u016f\u017eete do Harvest p\u0159idat svou polo\u017eku sledov\u00e1n\u00ed \u010dasu.<br/><br/>Pozn\u00e1mka: M\u016f\u017eete rovn\u011b\u017e kliknout na <b>Pamatovat si</b>, abyste nemuseli poka\u017ed\u00e9 zapisovat sv\u00e9 p\u0159ihla\u0161ovac\u00ed \u00fadaje Harvest.","label":"Harvest","form":{"harvest_note_info":"Tento text se p\u0159ipoj\u00ed na konec pozn\u00e1mky, spole\u010dn\u011b s protokolem str\u00e1ven\u00e9ho \u010dasu.","harvest_note":"Text pozn\u00e1mek","domain_info":"Zadejte jen samotnou dom\u00e9nu, bez https. Nap\u0159.: example.harvestapp.com","widget_title":"N\u00e1zev panelu","domain":"Dom\u00e9na"}},"zohocrm":{"desc":"Ve Freshdeku budou dostupn\u00e9 kontaktn\u00ed informace z CRM syst\u00e9mu Zoho.","helptext":"<h4>Zoho CRM Integration Help</h4><p><br/>To integrate Zoho CRM with Freshdesk, <a href='http://www.zoho.com/crm/help/api/using-authentication-token.html#Generate_Auth_Token' target='_blank'>Generate the Auth Token</a> in Zoho CRM through Browser Mode and paste the generated Auth Token here. If you already generated the Auth Token you can get it from <a href='https://accounts.zoho.com/u/h#setting/authtoken' target='_blank'>your accounts page.</a> <br/><br/>Once it is done you can view the contact information in any ticket or contact view.</p>","label":"Zoho CRM","form":{"api_key_info":"<a href='http://www.zoho.com/crm/help/api/using-authentication-token.html#Generate_Auth_Token' target='_blank'>Vygenerujte ov\u011b\u0159ovac\u00ed token</a> v CRM syst\u00e9mu Zoho prost\u0159ednictv\u00edm Browser Mode a vlo\u017ete tam vygenerovan\u00fd token.","api_key":"Ov\u011b\u0159ovac\u00ed token"}},"mailchimp":{"desc":"Add MailChimp to Freshdesk and start managing your subscriptions, export customer lists and pull necessary information about their activities from your help desk. ","helptext":"<h4>N\u00e1pov\u011bda pro propojen\u00ed na MailChimp</h4>","label":"MailChimp"},"new_freshplug":"Nov\u00fd FreshPlug","workflow_max":{"desc":"\u010cas str\u00e1ven\u00fd na ud\u00e1lostech m\u016f\u017eete protokolovat do sv\u00fdch \u010dinnost\u00ed a \u00fakol\u016f Workflow MAX.","helptext":"<h4>N\u00e1pov\u011bda k integraci aplikace Workflow Max</h4><p><br/> Chcete-li integrovat sledov\u00e1n\u00ed \u010dasu aplikace Workflow Max do aplikace Freshdesk, je nutn\u00e9 z\u00edskat kl\u00ed\u010d \u00fa\u010dtu a kl\u00ed\u010d rozhran\u00ed API od <a href='mailto:support@workflowmax.com'>podpory aplikace WorkflowMax</a>.  Integraci provedete zad\u00e1n\u00edm kl\u00ed\u010de do ur\u010den\u00fdch pol\u00ed. <br/><br/>Po dokon\u010den\u00ed integrace klikn\u011bte na libovoln\u00fd l\u00edstek a p\u0159ejd\u011bte na kartu Pracovn\u00ed v\u00fdkaz. Pot\u00e9 m\u016f\u017eete vybrat person\u00e1l, pr\u00e1ci a \u00falohu, ke kter\u00fdm chcete p\u0159idat \u010dasovou polo\u017eku v aplikaci Workflow Max.","label":"Workflow MAX","form":{"workflow_max_note_info":"Tento text se p\u0159ipoj\u00ed na konec pozn\u00e1mky, spole\u010dn\u011b se str\u00e1ven\u00fdm \u010dasem.","workflow_max_note":"P\u0159idan\u00fd text pozn\u00e1mek","api_key_info":"Po\u017eadujte kl\u00ed\u010d API pro podporu Workflow MAX a vlo\u017ete jej tak\u00e9 sem.","account_key":"Kl\u00ed\u010d \u00fa\u010dtu","api_key":"Kl\u00ed\u010d API","widget_title":"N\u00e1zev widgetu","account_key_info":"Po\u017eadujte kl\u00ed\u010d \u00fa\u010dtu pro podporu Workflow MAX a vlo\u017ete jej tak\u00e9 sem."}},"google_analytics":{"desc":"Zkontrolovat n\u00e1v\u0161t\u011bvnick\u00e9 statistiky na Va\u0161em port\u00e1lu podpory, pou\u017e\u00edvaj\u00edc\u00ed Google Analytics","portal":"Port\u00e1l","helptext":"<h4>N\u00e1pov\u011bda k integraci aplikace Google Analytics</h4><p><br/>V r\u00e1mci integrace aplikace Google Analytics do aplikace Freshdesk doporu\u010dujeme, abyste si vytvo\u0159ili vyhrazenou vlastnost uvnit\u0159 \u00fa\u010dtu sv\u00e9 firmy v aplikaci Google Analytics. <br/><br/>Chcete-li vytvo\u0159it vlastnost, p\u0159ihlaste se k \u00fa\u010dtu Google Analytics, p\u0159ejd\u011bte na kartu Administr\u00e1tora a zvolte po\u017eadovan\u00fd \u00fa\u010det. Pot\u00e9 kliknut\u00edm na polo\u017eku <b>Nov\u00e1 vlastnost</b> vytvo\u0159te novou vlastnost. U polo\u017eky <b>Adresa URL webu</b> zadejte adresu URL sv\u00e9ho port\u00e1lu podpory a klikn\u011bte na polo\u017eku <b>Vytvo\u0159it vlastnost</b>. Pak klikn\u011bte na vlastnost, kterou jste pr\u00e1v\u011b vytvo\u0159ili, na\u010de\u017e se hned pod n\u00e1zvem vlastnosti zobraz\u00ed <b>Identifik\u00e1tor vlastnosti</b>. Zkop\u00edrujte jej do nastaven\u00ed aplikace Google Analytics v aplikaci Freshdesk.</p>","label":"Google Analytics","account_number":"Zadejte sv\u00e9 sledovac\u00ed ID","inline_help":"Zadejte sledovac\u00ed ID pro ","form":{"google_analytics_settings":"&quot;&quot;","tracking_id":"Sledovac\u00ed ID pro ","tracking_id_example":"Nap\u0159.: UA-123456-1","copy_settings":"Pou\u017e\u00edt v\u00fd\u0161e uveden\u00e9 sledovac\u00ed ID pro v\u0161echny port\u00e1ly","google_analytics_settings_info":"&quot;&quot;"},"domain":"Dom\u00e9na"},"google_calendar":{"desc":"S kalend\u00e1\u0159em Google m\u016f\u017eete obsluhovat ud\u00e1losti pro v\u0161echny po\u017edavky.","helptext":"Kalend\u00e1\u0159 Google v\u00e1m umo\u017en\u00ed sledovat ud\u00e1losti spojen\u00e9 s po\u017edavky. Aby to bylo mo\u017en\u00e9, musej\u00ed z\u00e1stupci propojit sv\u016fj \u00fa\u010det na Google s FreshDeskem.","label":"Kalend\u00e1\u0159 Google","form":{"google_calendar_settings_info":" ","google_calendar_settings":"Nastaven\u00ed kalend\u00e1\u0159e Google"}},"freshplugs_title":"FreshPlugy","google_contacts":{"import_later_success":"Import kontakt\u016f Google byl \u00fasp\u011b\u0161n\u011b spu\u0161t\u011bn.  Stav importov\u00e1n\u00ed zjist\u00edte na str\u00e1nce nastaven\u00ed samotn\u00e9.","MERGE_REMOTE":"Slou\u010dit kontakty Freshdesku a Google (Google m\u00e1 p\u0159ednost)","desc":"Pravideln\u011b synchronizovat kontakty mezi Google a Freshdeskem.","not_yet_synced":"Synchronizace se je\u0161t\u011b nespustila.","OVERWRITE_LOCAL":"Exportovat kontakty Freshdesku a v\u0161echny aktualizace do kontakt\u016f Google","sync_group_info":"Ve va\u0161em \u00fa\u010dtu Gmail se vytvo\u0159\u00ed nov\u00e1 skupina kontakt\u016f <strong>%{group_name}</strong> pro synchronizov\u00e1n\u00ed kontakt\u016f.","email":"E-mail","OVERWRITE_REMOTE":"Importovat kontakty Google a v\u0161echny aktualizace do kontakt\u016f Freshdesku","tag_label":"Zna\u010dka synchronizace","last_sync_time":"\u010cas posledn\u00ed synchronizace","import_success":"\u00dasp\u011b\u0161n\u011b importov\u00e1ny kontakty Google.Stav: %{added} p\u0159id\u00e1no, %{updated} aktualizov\u00e1no %{deleted} odstran\u011bno.","import_complete":"Jednor\u00e1zov\u00fd import dokon\u010den.","MERGE_LATEST":"Slou\u010dit kontakty Freshdesku a Google (nov\u011bj\u0161\u00ed aktualizace m\u00e1 p\u0159ednost)","overwrite_existing_user":"P\u0159epsat existuj\u00edc\u00ed podrobnosti kontaktu ve Freshdesku","tag":"Nastaven\u00ed synchronizace","helptext":"<h4>N\u00e1pov\u011bda k nastaven\u00ed synchronizace kontakt\u016f Google</h4><p><br/> Kliknut\u00edm na <b>\u2018Synchronizovat nov\u00fd \u00fa\u010det\u2019</b> p\u0159idejte nov\u00fd \u00fa\u010det Google k synchronizov\u00e1n\u00ed. Po v\u00fdzv\u011b umo\u017en\u011bte Freshdesku p\u0159\u00edstup, aby mohl pou\u017e\u00edvat kontakty Google (podle pot\u0159eby zadejte sv\u00e9 u\u017eivatelsk\u00e9 jm\u00e9no a heslo Google).<br/><br/>\u00da\u010det m\u016f\u017eete vymazat, pokud jej ji\u017e nechcete synchronizovat.<br/><br/><b>Pozn\u00e1mka:</b> Doporu\u010dujeme p\u0159ed spu\u0161t\u011bn\u00edm synchronizace ulo\u017eit si z\u00e1lohu sv\u00fdch kontakt\u016f Google.","account_not_configured":"\u00da\u010det Google nen\u00ed \u0159\u00e1dn\u011b nakonfigurov\u00e1n. Pros\u00edm zkuste to znovu.","already_exist":"Tento e-mail ji\u017e byl nakonfigurov\u00e1n. Nelze p\u0159idat stejn\u00fd e-mail znovu.","group":"N\u00e1zev synchroniza\u010dn\u00ed skupiny","edit":"Upravit","OVERWRITE_REMOTE_small":"Importovat","import_problem":"Pot\u00ed\u017e s importov\u00e1n\u00edm kontakt\u016f Google.","delete_action":{"error":"Chyba p\u0159i odstra\u0148ov\u00e1n\u00ed \u00fa\u010dtu Google.","success":"Byl \u00fasp\u011b\u0161n\u011b odstran\u011bn \u00fa\u010det Google."},"import":"Importovat","no_status":"Nen\u00ed k dispozici","edit_form":{"import_group":"Zvolte skupiny k importu (voliteln\u00e9)","mail_box_detail":"Synchronizovat s","edit_app_title":"Upravit nastaven\u00ed synchronizace kontakt\u016f Google","import_title":"Nastaven\u00ed importu kontakt\u016f Google","install_title":"Nastaven\u00ed synchronizace kontakt\u016f Google"},"last_sync":"Posledn\u00ed synchronizace","info1":"Pou\u017eit\u00ed stejn\u00e9 zna\u010dky synchronizace ve v\u00edce \u00fa\u010dtech Google v\u00e1m umo\u017e\u0148uje sd\u00edlet kontakty Freshdesku mezi v\u0161emi \u00fa\u010dty.  Nechcete-li synchronizovat \u017e\u00e1dn\u00e9 kontakty do Google, ponechte je pr\u00e1zdn\u00e9.","edit_app":"Aktualizovat","account":"\u00da\u010det","import_success_no_stats":"\u00dasp\u011b\u0161n\u011b importov\u00e1ny kontakty Google.","label":"Synchronizace kontakt\u016f Google","last_sync_status":"Stav posledn\u00ed synchronizace","add_more":"Synchronizovat nov\u00fd \u00fa\u010det","syncing_in_progress":"Synchronizace prob\u00edh\u00e1","delete":"Smazat","sync_type":"Jak prov\u00e9st synchronizaci?","MERGE_REMOTE_small":"Slou\u010dit (Google m\u00e1 p\u0159ednost)","edit_helptext":"<h4>Google contacts sync help</h4><p><br/> <b>Select Groups to Import (optional)</b> <br/> Along with setting up Google synchronization, you can optionally import contacts from existing groups listed here. Please select the groups from which you want import contacts into Freshdesk.<br/><br/> <b>Sync Setting</b><br/> This setting controls syncing of contacts between Google and Freshdesk. Freshdesk contacts tagged with the specified <b>'Sync tag'</b> will be synced with Google. Also, contacts imported from Google will be tagged with that <b>'Sync tag'</b>.<br/><br/> A special group mentioned here will be created to sync contacts with Google. After the first time import, all contacts added to this group will be synced back to Freshdesk and vice versa.","install":"Importovat a aktivovat","internal_error":"Do\u0161lo k vnit\u0159n\u00ed chyb\u011b.  Kontaktujte pros\u00edm podporu.","MERGE_LOCAL_small":"Slou\u010dit (Freshdesk m\u00e1 p\u0159ednost)","update_action":{"error":"Chyba p\u0159i aktualizaci \u00fa\u010dtu Google.","also":"Tak\u00e9 ","success":"Byl \u00fasp\u011b\u0161n\u011b p\u0159id\u00e1n \u00fa\u010det Google."},"form":{"account_settings_info":"&quot;&quot;","account_not_configured":"<br/>Nastaven\u00ed \u00fa\u010dtu Google je\u0161t\u011b nejsou nakonfigurov\u00e1na. Kliknut\u00edm na '%{action}' nakonfigurujte nov\u00fd \u00fa\u010det s Google.<br/><br/>","sync_type":"Typ synchronizace","account_settings":"&quot;&quot;","sync_type_info":"jak chcete synchronizovat kontakty mezi Google a Freshdeskem."},"sync_status":{"modified":"zm\u011bn\u011bno","added":"p\u0159id\u00e1no","deleted":"smaz\u00e1no","google":"Exportov\u00e1n stav kontakt\u016f v Google","freshdesk":"Importov\u00e1n stav kontakt\u016f ve Freshdesku"},"MERGE_LOCAL":"Slou\u010dit kontakty Freshdesku a Google (Freshdesk m\u00e1 p\u0159ednost)","enable_integration":"Spustit automatickou synchronizaci po dokon\u010den\u00ed importu (jednou denn\u011b).","OVERWRITE_LOCAL_small":"Exportovat","fetch_problem":"Pot\u00ed\u017e s p\u0159eb\u00edr\u00e1n\u00edm kontakt\u016f Google."},"constantcontact":{"desc":"Integrate your Constant Contact account to control your subscriptions inside Freshdesk and get updated information about customers and their activities.","helptext":"<h4>N\u00e1pov\u011bda k propojen\u00ed na Constant Contact</h4>","label":"Constant Contact"},"native_integrations":"Nativn\u00ed propojen\u00ed","salesforce":{"desc":"You can view contact information from Salesforce in Freshdesk.","label":"Salesforce","form":{"salesforce_settings":"Nastaven\u00ed Salesforce","salesforce_settings_info":"\"\""}},"no_freshplugs":"Nem\u00e1te \u017e\u00e1dn\u00fd FreshPlug.","freshplugs":{"show_preview":"Uk\u00e1zat n\u00e1hled","hide_preview":"Schovat n\u00e1hled","custom_widget_preview":"N\u00e1hled u\u017eivatelsk\u00e9ho panelu","show_widget_in_ticket_view_page":"Uk\u00e1zat panel na str\u00e1nce po\u017eadavku.","show_the_widget_in_contact_view_page":"Uk\u00e1zat panel na str\u00e1nce kontakt\u016f.","refresh":"Obnovit"}}}};