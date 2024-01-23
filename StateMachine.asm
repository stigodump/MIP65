;**************************************************
;**************************************************
;State machine Status
; 
;**************************************************
ST_TX_BUSY_b		= 0
ST_RX_BUSY_b		= 1
ST_CONNECTED_b 		= 2 
ST_DHCP_STATIC_b	= 3
ST_NETWORK_UP_b		= 4
ST_RUN_CMD_b		= 7

ST_TX_BUSY			= 1<<ST_TX_BUSY_b
ST_RX_BUSY			= 1<<ST_RX_BUSY_b
ST_CONNECTED 		= 1<<ST_CONNECTED_b
ST_DHCP_STATIC 		= 1<<ST_DHCP_STATIC_b	;DHCP = 1, Static = 0
ST_NETWORK_UP		= 1<<ST_NETWORK_UP_b
ST_RUN_CMD 			= 1<<ST_RUN_CMD_b

TX_TIMEOUT		= 4

		.section base_page_ram
rx_timer 			.fill 1
tx_timer			.fill 1
state 				.fill 1
		.send

		.section ram_data
timeout_pntr		.fill 2
		.send

		.section rom_code

;**************************************************
;**************************************************
;Initialise	state machine
; 
;**************************************************
Initialise			ldx #$ff	;Clear all state bits
					jsr FinishEvent
					ldz #DataTypes.MESSAGES.cable_discon
					bra msg_exit
					
;**************************************************
;**************************************************
;Task sucesfully completed, sets cmd status to complete
; A = State bits to SET, if none must be 0
; X = State bits to CLR, if none must be 0
; 
;**************************************************
FinishEvent			tsb state
					txa
					ora #ST_RX_BUSY
					trb state
					lda #<sm_exit
					sta timeout_pntr
					lda #>sm_exit
					sta timeout_pntr+1
					ldz #DataTypes.MESSAGES.cmd_complete
					;Is there a command cued to execute
					bbs ST_RUN_CMD_b,state,+
					bra msg_exit
					;Execute user command
+					rmb ST_RUN_CMD_b,state
					jmp Command.Execute

;**************************************************
;**************************************************
;User request received event
; A = TX - RX events to set
;Optional: Only needed if setting RX timeout
; X = <rx timeout pointer
; Y = >rx timeout pointer
; Z = rx time out time in seconds
; 
;**************************************************
					;Is state busy
SetEvent			bbs ST_RX_BUSY_b,state,busy_exit
					bbs ST_TX_BUSY_b,state,busy_exit
					;Set the state bits in A
					and #ST_TX_BUSY|ST_RX_BUSY
					beq sm_exit
					ora state
					sta state
					;Is RX bit set
					bbr ST_RX_BUSY_b,state,+
					stx timeout_pntr
					sty timeout_pntr+1
					stz rx_timer
					;is TX bit set
+					bbr ST_TX_BUSY_b,state,+
					lda #TX_TIMEOUT
					sta tx_timer
+					ldz #DataTypes.MESSAGES.status_busy
					bra msg_exit
busy_exit			lda #0
					rts
					
;**************************************************
;**************************************************
;Second timer event
; 
;**************************************************
TimerEvent			bbr ST_TX_BUSY_b,state,+
					dec tx_timer
					bne +
					ldz #DataTypes.MESSAGES.send_failed
					lda #1 					;Network error
					bbs ST_RX_BUSY_b,state,rx_timeout
					bra ErrorEvent

+					bbs ST_RX_BUSY_b,state,+
-					rts
+					dec rx_timer
					bne -
					lda #0					;Normal timeout		
rx_timeout			jmp (timeout_pntr)

;**************************************************
;**************************************************
;Cable connected event
; 
;**************************************************
ConnectionEvent 	lda #ST_CONNECTED
					tsb state
					ldz #DataTypes.MESSAGES.cable_connected
					bra msg_exit

;**************************************************
;**************************************************
;Cable disconnected event
; 
;**************************************************
DisConnEvent 		lda #ST_CONNECTED|ST_NETWORK_UP|ST_DHCP_STATIC
					trb state
					ldz #DataTypes.MESSAGES.cable_discon
					bbr ST_RX_BUSY_b,state,ErrorEvent
					lda #1 					;Network error
					jmp (timeout_pntr)					

;**************************************************
;**************************************************
;Set connected state in state machine
; 
;**************************************************
SetConnected		lda #ST_CONNECTED
					tsb state
					lda #ST_DHCP_STATIC
					trb state
					ldz #DataTypes.MESSAGES.cmd_complete

;**************************************************
;**************************************************
;Error event, reset state machine
; 
;**************************************************
ErrorEvent 			lda #ST_RX_BUSY|ST_TX_BUSY|ST_RUN_CMD
					trb state
					bra msg_exit

;**************************************************
;**************************************************
;Ethernet packet sent event enty point
; 
;**************************************************
TXEvent				rmb ST_TX_BUSY_b,state
					ldz #DataTypes.MESSAGES.cmd_complete
					lda state
					and #ST_TX_BUSY|ST_RX_BUSY
					bne sm_exit
					
;**************************************************
;**************************************************
;Set command status message
; 
;**************************************************
					;Set command status massage
msg_exit			stz Command.usr_cmd_list.result
					lda state
					and #$ff^ST_RUN_CMD
					sta Command.network_status.status
sm_exit				rts

		.send

