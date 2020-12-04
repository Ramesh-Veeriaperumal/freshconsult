# Freshconsult
Choose from range of consultant services and schedule online appointment while sitting at home.

# Usage
Enable FSM and you will get new set of ticket fields and a new automation rule that will set the type of ticket as consultation type
Appointment time
Add Payment
Add Payment
Preffered Communication Type
Preffered Appointment Duration

When the agent will update the ticket with Appointment time and select the add payment check box
1. A payment link will be generated (using Paypal)
2. A zoom meeting will be created.
       Both payment link and meeting url are saved in schema_less_ticket serialised column.
3. A note is created with the payment link and the meeting url

Also a reminder notification service will be running in background which will notify (send mail) the end user(actual customer) and the consultant before 30 minutes of every appointment.
The customers will get periodic updates about their scheduled appointment.
