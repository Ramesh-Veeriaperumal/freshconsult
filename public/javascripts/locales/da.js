var I18n = I18n || {};
I18n.translations = {"da":{"integrations":{"workflow_max":{"desc":"Du kan logge tid brugt p\u00e5 billetterne til din Workflow Max jobs og opgaver.","helptext":"<h4>Workflow Max Integration Hj\u00e6lp</h4><p><br/> For at integrere Workflow Max tidsregistrering med Freshdesk, er du n\u00f8dt til at f\u00e5 Konto N\u00f8glen  og API N\u00f8glen fra <a href='mailto:support@workflowmax.com'>WorkflowMax Support</a>.  Indtast n\u00f8glerne i de angivne felter for at fuldende integreringen. <br/><br/>N\u00e5r integreret, klik p\u00e5 en billet og g\u00e5 til Tidsstyring fanen. Du kan derefter v\u00e6lge det personale, job og opgave du vil tilf\u00f8je til tidspunkt poster i Workflow Max.","label":"Workflow Max","form":{"workflow_max_note_info":"Denne tekst vil blive h\u00e6ftet til slutningen af bem\u00e6rkningen, sammen med den indtastede tid.","workflow_max_note":"Note-tekst skal tilf\u00f8jes","account_key":"Konto N\u00f8gle","widget_title":"Widget Titel","account_key_info":"Anmod om din Konto N\u00f8gle fra Workflow Max support og inds\u00e6t den her.","api_key":"API N\u00f8gle","api_key_info":"Anmod om din API N\u00f8gle fra Workflow Max support og inds\u00e6t den her."}},"jira_settings":{"update_jira_status":"Opdater JIRA status","send_reply_in_fd":"Underret kunde via e-mail","add_public_note_in_fd":"Tilf\u00f8j en offentlig bem\u00e6rkning i Freshdesk.","update_status_in_fd":"Opdater status i Freshdesk.","none":"G\u00f8r intet.","add_private_note_in_fd":"Tilf\u00f8j en privat bem\u00e6rkning i Freshdesk og send meddelelse til agent.","add_comment_in_jira":"Tilf\u00f8j en kommentar i JIRA"},"salesforce":{"desc":"You can view contact information from Salesforce in Freshdesk.","label":"Salesforce","form":{"salesforce_settings":"Salesforce Indstillinger"}},"harvest":{"desc":"Du kan logge tid brugt p\u00e5 billetter i dine Harvest projekter og opgaver.","helptext":"<h4>Harvest Integration Hj\u00e6lp</h4><p><br/>For at integrere Harvest med Freshdesk, skal du indtaste dit <b>Dom\u00e6ne navn</b> og klikke p\u00e5 Aktiver.<br/><br/>Klik p\u00e5 en billet, g\u00e5 til <b>Tidsstyrring fanen</b>.  Du kan derefter indtaste dit Harvest <b>Brugernavn</b> og <b>Adgangskode</b> for at logge ind. Nu kan du tilf\u00f8je din tidsf\u00f8rsel til  Harvest.<br/><br/>Bem\u00e6rk: Du kan klikke p\u00e5 <b>Husk mig</b>, s\u00e5 du ikke beh\u00f8ver at indtaste dine Harvest detaljer hver gang.","label":"Harvest","form":{"domain":"Dom\u00e6ne","widget_title":"Widget Titel","harvest_note_info":"Denne tekst skal tilf\u00f8jes i slutningen af bem\u00e6rkningen, sammen med tid brugt log.","domain_info":"Indtast dom\u00e6net alene uden https. Fx: eksempel.harvestapp.com","harvest_note":"Bem\u00e6rkninger tekst"}},"capsule_crm":{"helptext":"<h4>Link tilbage fra Capsule til Freshdesk</h4><p><br/>Du kan oprette et link i Capsule CRM for at se kontaktens billetter i Freshdesk.</p> <p>For at g\u00f8re dette g\u00e5 til <br /><b>Indstillinger -> Brugerdefinerede felter -> For Folk & Organisation</b></p><p> Klik derefter p\u00e5 \"Tilf\u00f8j ny...\" og v\u00e6lg <b>\"Genereret link\"</b></p> <p> Kopier URL n\u00f8jagtigt som vist herunder og inds\u00e6t den i Capsule CRM som led definition<span class=\"info-code\">http://%{full_domain}/helpdesk/tickets?email={email}</span></p>","label":"Capsule CRM"},"google_contacts":{"no_status":"N/A","edit_helptext":"<h4>Google contacts sync help</h4><p><br/> <b>Select Groups to Import (optional)</b> <br/> Along with setting up Google synchronization, you can optionally import contacts from existing groups listed here. Please select the groups from which you want import contacts into Freshdesk.<br/><br/> <b>Sync Setting</b><br/> This setting controls syncing of contacts between Google and Freshdesk. Freshdesk contacts tagged with the specified <b>'Sync tag'</b> will be synced with Google. Also, contacts imported from Google will be tagged with that <b>'Sync tag'</b>.<br/><br/> A special group mentioned here will be created to sync contacts with Google. After the first time import, all contacts added to this group will be synced back to Freshdesk and vice versa.","delete_action":{"error":"Fejl under sletning af Google-konto.","success":"Google-konto slettet."},"sync_group_info":"En ny kontaktgruppe <strong>%{group_name}</strong> vil blive oprettet i din Gmail konto til de synkroniserede kontakter.","MERGE_LOCAL":"Sammenflet Freshdesk og Google kontakter (Freshdesk forrang)","desc":"Periodisk synkronisere kontakter mellem Google og Freshdesk.","enable_integration":"Start automatisk synkronisering efter import fuldf\u00f8rt (daglig).","MERGE_LOCAL_small":"Sammenflet (Freshdesk forrang)","tag_label":"Synk. Tag","MERGE_REMOTE":"Sammenflet Freshdesk og Google kontakter (Google forrang)","already_exist":"Denne e-mail er allerede konfigureret. Du kan ikke tilf\u00f8je den samme e-mail igen.","MERGE_REMOTE_small":"Sammenflet (Google forrang)","internal_error":"En intern fejl opstod. Kontakt venligst support.","OVERWRITE_LOCAL":"Eksporter Freshdesk kontakter og eventuelle ajourf\u00f8ringer i Google kontakter","group":"Synkroniser Gruppe navn","import_success":"Successfully imported Google contacts. Status: %{added} Added, %{updated} Updated and %{deleted} Deleted.","OVERWRITE_REMOTE":"Importer Google-kontakter og eventuelle ajourf\u00f8ringer i Freshdesk kontakter","import_complete":"Engangs import afsluttet.","last_sync_time":"Sidste synkronisering tid","edit":"Rediger","add_more":"Synkroniser ny konto","import":"Importer","helptext":"<h4>Google-kontaktpersoner synkronisering setup hj\u00e6lp</h4><p><br/> Klik p\u00e5 <b>\u2018Synkroniser ny konto\u2019</b> for at tilf\u00f8je en ny Google konto til synkronisering. N\u00e5r du bliver bedt om det, skal du lade Freshdesk bruge Google kontakter (Indtast dit Google brugernavn & adgangskode hvis du bliver bedt om det).<br/><br/>Du kan slette en konto hvis du ikke l\u00e6ngere vil synkronisere med denne konto mere.<br/><br/><b>Bem\u00e6rk:</b> Det anbefales at du gemmer en bavkup af dine Google kontakter for synkronisering.","overwrite_existing_user":"Overskriv eksisterende kontaktoplysninger i Freshdesk","import_success_no_stats":"Google-kontakter importeret.","MERGE_LATEST":"Sammenflet Freshdesk og Google kontakter (Seneste opdatering forrang)","tag":"Synk. Indstillinger","OVERWRITE_LOCAL_small":"Eksporter","syncing_in_progress":"Synkronisering i gang","install":"Importer & Aktiver","label":"Google kontakter synkronisering","delete":"Slet","OVERWRITE_REMOTE_small":"Importer","import_problem":"Problemer med at importere Google-kontakter.","edit_form":{"import_title":"Google-kontakter import indstilling","install_title":"Google-kontakter synkronisering indstilling","import_group":"V\u00e6lg grupper til at importere (valgfrit)","edit_app_title":"Rediger Google-kontakter synkronisering indstilling","mail_box_detail":"Synkroniser med"},"not_yet_synced":"Synkronisering ikke startet.","info1":"Brug samme synkronisering tags p\u00e5 tv\u00e6rs af flere Google-konti giver dig mulighed for at dele Freshdesk kontakter med alle konti. Hvis du ikke vil synkronisere alle kontakter i Google, kan du lade den v\u00e6re tom.","account_not_configured":"Google-konto er ikke konfigureret korrekt. Pr\u00f8v venligst igen.","account":"Konto","sync_status":{"added":"tilf\u00f8jet","deleted":"slettet","freshdesk":"Importerede Kontakter status i Freshdesk","modified":"modificeret","google":"Importerede Kontakter status i Google"},"last_sync_status":"Sidste synkronisering status","fetch_problem":"Problem med at hente Google-kontakter.","edit_app":"Opdat\u00e9r","import_later_success":"Google-kontakter import startede uden problemer. Du kan kontrollere import status i indstillingerne p\u00e5 selve siden.","update_action":{"error":"Fejl under opdateringen af Google-konto.","success":"Google-konto tilf\u00f8jet.","also":"Ogs\u00e5"},"email":"E-mail","form":{"sync_type_info":"Hvordan vil du synkronisere kontakterne mellem Google og Freshdesk.","account_not_configured":"<br/>Google-kontoindstillinger er endnu ikke konfigureret. Klik p\u00e5 '%{action}' for at konfigurere ny konto hos Google.<br/><br/>","sync_type":"Synkroniseringstype"}},"logmein":{"desc":"Giv \u00f8jeblikkelig fjernsupport til dine kunder og medarbejdere med LogMeIn Rescue","helptext":"<h4>LogMeIn Rescue Integration Hj\u00e6lp</h4><p><br/> For at integrere LogMeIn Rescue med Freshdesk, skal du indtaste dit LogMeIn Rescue FirmaID og SSO adgangskode og klikke p\u00e5 Opdater. <br/>N\u00e5r aktiveret kan en, LogMeIn Rescue widget findes i billetdetaljer siden. <br/><br/>Brug  &quot;K\u00f8r Tekniker Konsol&quot; for at lancere tekniker konsolen direkte fra denne Freshdesk Widget. <br/>Nu kan du generere en pinkode og dele instruktionerne med rekvienten for at forts\u00e6tte supporten i LogMeIn Rescue. <br/><br/> <b>Bem\u00e6rk:</b> Agentens e-mail skal matche LogMeIn Rescue's tekniker SSO ID. For at indstille dit SSO ID g\u00e5 til Admin Center -> Tekniket Navn -> Organisation -> SSOID","label":"LogMeIn Rescue","note":{"tech_name":"Tekniker Navn","header":"Din LogMeIn Rescue Session detaljer","work_time":"Total arbejdstid (i sekunder)","session_id":"Session ID","chatlog":"Chat Log","tech_email":"Tekniker E-mail","tech_notes":"Tekniker Notater","platform":"Slutbruger Platform"},"form":{"company_id":"Firma ID","logmein_sso_pwd_info":"For at s\u00e6tte din SSO adgangskode, g\u00e5 til Admin Center -> Tekniker Gruppe -> Globale Indstillinger -> Single Sign-On -> ny SSO adgangskode","widget_title":"Widget Titel","logmein_company_info":"For at f\u00e5 dit Firma ID, g\u00e5 til Admin Center -> Tekniker Gruppe -> Globale Indstillinger -> ASP.Net C# server side eksempel ","password":"SSO kodeord"}},"freshbooks":{"desc":"Du kan logge tid brugt p\u00e5 billetter i dine FreshBooks projekter og opgaver.","helptext":"<h4>Freshbooks Integration Hj\u00e6lp</h4><p><br/>For at integrere Freshbooks med Freshdesk, skal du f\u00f8rst f\u00e5 fat p\u00e5 Freshbooks API & Autentificeringstoken. <br/><br/>Log ind p\u00e5 din Freshbooks konto, klik p\u00e5 din <b>Personale fane</b> og g\u00e5 til <b>Personale og Entrepren\u00f8rer underfanen</b>. Klik p\u00e5 <b>Rediger</b> i din Admin.  Du kan finde din API URL og Autentificeringstoken.<br/><br/>I Freshdesk, skal du klikke p\u00e5 en billet og g\u00e5 til Tidsregistrering fanen. Du kan derefter tilf\u00f8je din tidsregistrering til FreshBooks.","label":"Freshbooks","form":{"freshbooks_note":"Bem\u00e6rkninger tekst","api_url_info":"Indtast den komplette API URL med https. Fx: https://example.freshbooks.com/api/2.1/xml-in","freshbooks_note_info":"Denne tekst vil blive h\u00e6ftet til slutningen af bem\u00e6rkningen, sammen med den indtastede tid.","widget_title":"Widget Titel","api_url":"API URL","api_key":"Autentificeringstoken"}},"custom_application":{"description":"Beskrivelse","desc":"Du kan tilf\u00f8je en brugerdefineret widget til at vise detaljer ved hj\u00e6lp af dit egen brugerdefinerede script.","script":"Script","small_help_text":"Du kan oprette dine egne brugerdefinerede widgets ved hj\u00e6lp af html,css og javascript","edit":"Rediger Brugerdefineret Widget","helptext":"<h4>Brugerdefineret Widget Hj\u00e6lp</h4><p><br/> Du kan oprette dine egne brugerdefinerede widgets ved hj\u00e6lp af html,css og javascript.</br></br>For at oprette den brugerdefinerede widget, skal du indtaste navnet p\u00e5 din nye widget og en kort beskrivelse af den.</br>Indtast din kode under \u2018Script\u2019.  Du kan referere til vores l\u00f8sningsside for at l\u00e6re mere om scriptet.</br></br>Du kan klikke <b>\u2018Vis Eksempel\u2019</b> for at se hvordan din widget vil se ud, b\u00e5de i billetten og p\u00e5 kontaktsiderne.","label":"Brugerdefineret Widget","name":"Navn","form":{"insert_placeholder":"Inds\u00e6t Pladsholder","widget_title":"Widget Navn","widget_script":"Widget kode snippet","create_n_enable":"Opret og Aktiver"},"new":"Ny Brugerdefineret Widget"},"jira":{"desc":"Konverter billetter til emner, der kan spores i JIRA.","helptext":"<h4>JIRA Integration Help</h4><p><br/>To integrate JIRA with Freshdesk, enter your JIRA administrator username and password. The integration supports both on-demand and on-premise variants, from JIRA 4.2 upto the latest version - JIRA 5.<br/><br/> To create an issue or link to an existing issue from Freshdesk, navigate to the Tickets page and click on <img src='/images/ticket-icon/jira.png'/><br/><br/> To view details of your linked Freshdesk tickets in JIRA, and conversely to view JIRA issue details in Freshdesk, the JIRA administrator is recommended to create a Free Text custom field with the name &quot;Freshdesk Tickets&quot; as described below. <br/><br/>Log on to your JIRA account, click on <b>Administration</b>, navigate to <b>Issues</b> -> <b>Fields</b> and click on <b>Add Custom Field</b>. In <b>Create Custom Field</b> screen, select <b> Free Text Field </b> and click on <b>Next</b>. Input <b>&quot;Freshdesk Tickets&quot;</b> in Field Name and click on Finish. In <b>Associate field to Screens</b> page, select all the check-boxes and click on 'Update'.<br/><br/>","label":"Atlassian JIRA","form":{"jira_note_info":"Denne tekst vil blive tilf\u00f8jet til emne beskrivelsen i JIRA.","domain":"Dom\u00e6ne","jira_status_sync":"For enhver \u00e6ndring i JIRA emnestatus %{dropdown}","add_note":"Tilf\u00f8j det som en privat note.","update_jira_status":"Opdater ogs\u00e5 JIRA status","jira_comment_sync":"For enhver kommentar tilf\u00f8jet i JIRA emne %{dropdown}","fd_comment_sync":"For enhver kommentar tilf\u00f8jet i Freshdesk %{dropdown}","username":"Brugernavn","add_jira_comment":"Tilf\u00f8j det som en kommentar i JIRA.","widget_title":"Widget Titel","send_reply":"Send det som svar til kunden.","jira_status_sync_update_field":"Opdater Freshdesk statusfelt.","password":"Kodeord","domain_info":"Indtast den komplette JIRA konto URL med https/http. Fx. https://example.atlassian.net. <br /><span class='italics'> Bem\u00e6rk: De fysiske varianter af JIRA b\u00f8r uds\u00e6ttes for internettet. </span>","jira_status_sync_update_customer":"Send svar til kunden og opdater statusfelt.","fd_status_sync":"For enhver \u00e6ndring i Freshdesk status %{dropdown}","jira_note":"Beskrivelsestekst","do_nothing":"G\u00f8r intet."}},"google_analytics":{"domain":"Dom\u00e6ne","desc":"Overv\u00e5g statistik om bes\u00f8gende p\u00e5 din support portal ved hj\u00e6lp af Google Analytics","account_number":"Indtast dit Tracking ID","helptext":"<h4>Google Analytics Integration Hj\u00e6lp</h4><p><br/>For at integrere Google Analytics med Freshdesk, anbefales det at du opretter en dedikeret ejendom indeni dit firmas konto hos Google Analytics. <br/><br/>For at oprette en ejendom, skal du logge ind p\u00e5 din Google Analytics konto og g\u00e5 til din Admin fane og v\u00e6lge den \u00f8nskede konto. Klik p\u00e5 <b>'Ny Ejendom'</b> for at oprette en. I '<b>Hjemmeside URL'</b>, skal du indtast din Support Portals URL og klikke p\u00e5 <b>'Opret Ejendom'</b>. Nu skal du klikke p\u00e5 ejendommen du har oprettet og du vil kunne se <b>'Ejendom ID'</b> lige under ejendom navn. Kopier dette til Google Analytics Indstillinger i Freshdesk.</p>","portal":"Portal","label":"Google Analytics","inline_help":"Indtast Tracking ID for","form":{"tracking_id":"Tracking ID for ","copy_settings":"Brug det ovenst\u00e5ende Tracking ID for alle portaler","tracking_id_example":"F.eks.: UA-123456-1"}},"capsule":{"desc":"Du kan se kontaktoplysninger fra Capsule CRM i Freshdesk. Denne information kan tilg\u00e5s p\u00e5 Billetdetaljer siden og Kontaktdetaljer siden.","label":"Capsule CRM","form":{"domain":"Dom\u00e6ne","bcc_drop_box_mail_info":"Du kan finde din unikke Capsule Drop box e-mailadresse under <b>\u201cIndstillinger -> Mail Drop Box\u201d</b>.<br /> (Du kan finde denne i \u00f8verste h\u00f8jre hj\u00f8rne af siden. ).<br /> Kopier e-mailadresse og inds\u00e6t den i tekstfeltet ovenfor.<br />  Freshdesk vil automatisk tilf\u00f8je denne e-mailadresse til feltet Bcc, n\u00e5r du besvarer en Billet","bcc_drop_box_mail":"Mail Drop Box-adresse","widget_title":"Widget Titel","domain_info":"Indtast dom\u00e6net uden https. Fx: eksempel.capsulecrm.com","api_key":"Api N\u00f8gle","api_key_info":"For at f\u00e5 din unikke API n\u00f8gle, skal du logge ind p\u00e5 din Capsule CRM-konto og navigere til <br /> <b>\u201cBruger -> My Pr\u00e6ferencer\u201d</b>.  (Du kan finde dette i \u00f8verste h\u00f8jre hj\u00f8rne af siden).<br /> Klik p\u00e5 <b>\u201cAPI Autentificeringstoken\u201d</b>, og for at f\u00e5 den unikke API-n\u00f8gle. <br /> Kopier n\u00f8glen og inds\u00e6t den i tekstfeltet ovenfor."}},"sugarcrm":{"desc":"Du kan se kontaktoplysninger fra SugarCRM i Freshdesk.","helptext":"<h4>Sugar CRM Integration Hj\u00e6lp</h4><p><br/> Du kan f\u00e5 adgang til din SugarCRM kontaktinformation i Freshdesk billetten & kontaktsiderne. <br /><br /> De f\u00f8lgende datapunkter vil v\u00e6re tilg\u00e6ngelige - navn, titel, firma, addeling, kontaktadresse, telefon- & mobilnumre. <br /><br />Bem\u00e6rk venligst at s\u00f8gefunktionen er baseret p\u00e5 e-mailadressen. Hvis der er flere kontaker med den samme e-mailadresse, vil de alle blive vist p\u00e5 en liste.","label":"SugarCRM","form":{"domain":"SugarCRM Konto URL","username":"Brugernavn","widget_title":"Widget Titel","password":"Kodeord","domain_info":"For eksempel hvis din  SugarCRM URL er <strong>http://mycompany.xyz/sugar/index.php?module=Administration&action=index</strong> , indtast <strong> http://mycompany.xyz/sugar </strong><br /><br /> Bem\u00e6rk: Den fysiske variant af SugarCRM skal v\u00e6re forbundet til internettet. </span>"}}}}};