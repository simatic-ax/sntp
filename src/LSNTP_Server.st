//=============================================================================
// SIEMENS AG / (c)Copyright 2020
//-----------------------------------------------------------------------------
// Title:        LSNTP_Server
// Function:     SNTP server implementation according to RFC 4330 using UDP.
//               This FB answers NTP Client requests. The internal clock is
//               used as source.
// Library:      LSNTP
// Author:       Siemens Industry Online Support
// Tested with:  CPU 1516-3 PN/DP FW 2.8
// Engineering:  Simatic AX
// Restrictions: --
// Requirements: S7-1200 CPU with FW V4.0 or higher
//               S7-1500 CPU with FW V2.0 or higher
//-----------------------------------------------------------------------------
// Change log table:
// Version  | Date       | Expert in charge       | Changes applied
//----------|------------|------------------------|------------------------------
// 01.00.00 | 01.10.2013 | GER I S WEST IA APPS   | First released version
// 02.00.00 | 01.02.2016 | Online Support         | Migration to TIA Portal V13 SP1
//                                                | Application of programming style guide S7-1200/1500
// 02.01.00 | 19.04.2017 | Online Support         | Upgraded to TIA Portal V14
//                                                | Added "hwID" to interface
// 03.00.00 | 01.10.2017 | Online Support         | Replaced "TCON_Param" with "TCON_IP_V4"
//                                                | Fixed error in calculation of fractional part
// 03.00.01 | 17.05.2018 | Online Support         | Fixed error in calculation of reference timestamp if "lastTimeSet" is before 1990
// 03.00.02 | 31.07.2019 | Online Support         | Upgraded to TIA Portal V15.1
//                                                | Activated simulation support
// 04.00.00 | 28.04.2021 | Online Support         | Implemented PLCopen template, added status codes for more information
// 05.00.00 | 29.10.2024 | Contiweb B.V.          | Migration to Simatic AX
//=============================================================================

USING Siemens.Simatic.S71500.Clocks;
USING Siemens.Simatic.S71500.Communication.OUC;
USING System.DateTime;

NAMESPACE Simatic.Ax.sntp

    FUNCTION_BLOCK LSNTP_Server

        VAR_INPUT
            /// TRUE: Enable functionality of FB
            enable                      : BOOL              := FALSE;
            /// Hardware identifier of Ethernet interface
            hwID                        : UINT              := UINT#64;
            /// Internal connection ID used for TURCV and TUSEND
            connID                      : WORD;
            /// The input specifies from which time source the server CPU obtains the time:
            ///     • 0: uncalibrated (set "by hand")
            ///     • 1: primary reference (e.g., DCF 77)
            ///     • 2: secondary reference (e.g., from GPS receiver)
            /// The information is passed on to the NTP client in the SNTP protocol.
            referenceID                 : USINT;
            /// Date and time when the time was set last. Set only if external reference is used.
            lastTimeSet                 : LDATE_AND_TIME    := LAST_TIME_SET_1990;
        END_VAR

        VAR_OUTPUT
            /// Date and time when the time was set last. Set only if external reference is used.
            valid                       : BOOL;
            /// TRUE: FB is not finished and new output values can be expected
            busy                        : BOOL;
            /// TRUE: FB is not finished and new output values can be expected
            error                       : BOOL;
            /// 16#0000-16#7FFF: Status of the FB, 16#8000 - 16#FFFF: Error identification
            status                      : WORD              := STATUS_NO_CALL;
            /// Diagnostics information of FB
            diagnostics                 : typeDiagnostics;
        END_VAR

        VAR
            /// Old value of 'enable' input for edge detection
            statEnableOld               : BOOL;
            /// Static value for output 'valid'
            statValid                   : BOOL;
            /// Static value for output 'busy'
            statBusy                    : BOOL;
            /// Static value for output 'error'
            statError                   : BOOL;
            /// Static value for output 'busy'
            statErrorUserCleared        : BOOL;
            /// Error occurred that can be acknowledged by FB
            statErrorAutoCleared        : BOOL;
            /// Static value for output 'status'
            statStatus                  : WORD              := STATUS_NO_CALL;
            /// Status or return value of called FBs, FCs and system blocks
            statSubfunctionStatus       : WORD;
            /// State in the state machine of the FB
            statFBErrorState            : DINT;
            /// State in the state machine of the FB
            statFBState                 : DINT              := FB_STATE_NO_PROCESSING;
            /// TRUE: Disabling has been completed
            statDisablingCompleted      : BOOL;
            /// Empty diagnostics information (for initialization purposes only)
            statEmptyDiagnostics        : typeDiagnostics;
            /// Instance of TCON
            instTCon                    : Connect;
            /// Instance of TURCV
            instTURcv                   : UdpReceive;
            /// Instance of TUSEND
            instTUSend                  : UdpSend;
            /// Instance of TDISCON
            instTDiscon                 : Disconnect;
            /// Parameters
            statConParam                : ConnectionConfiguration;
            /// Address of the client
            statAddr                    : RemoteAddressConfiguration;
            /// Telegram received from client
            statTelegramRcvd            : LSNTP_typeTelegram;
            /// Telegram to send to client
            statTelegramSend            : LSNTP_typeTelegram;
            /// Telegram buffer received and send Client
            statTelegramBuffer          : ARRAY[0..(LEN_SNTP - 1)] OF BYTE;
        END_VAR

        VAR_TEMP
            /// Temporary value for input 'enable'
            tempEnable                  : BOOL;
            /// System time
            tempSysTime                 : LDATE_AND_TIME;
            /// Actual year from the system time
            tempSysTimeYear             : INT;
            /// Number of chars that were converted
            tempNumChar                 : UINT;
            /// Temporary index for loops
            tempIndex                   : INT;
        END_VAR

        VAR CONSTANT
            /// Length of SNTP telegram without authentication
            LEN_SNTP                    : INT               := 48;
            /// Ignore time that's older than this year
            INVALID_YEAR                : UINT              := UINT#2010;
            /// Clock Precision -6 = -0,015625s (for S7-1200)
            CLOCK_PRECISION             : BYTE              := BYTE#16#FA;
            /// Standard last time set
            LAST_TIME_SET_1990          : LDATE_AND_TIME    := LDT#1990-01-01-00:00:00;
            /// Mask mode
            MASK_MODE                   : BYTE              := BYTE#2#00000111;
            /// Mode: client
            MODE_CLIENT                 : BYTE              := BYTE#2#00000011;
            /// LI: No warning, VN: 3, Mode: server
            MODE_SERVER                 : BYTE              := BYTE#2#00011100;
            /// FB state: No processing
            FB_STATE_NO_PROCESSING      : DINT              := DINT#0;
            /// FB state: Enabling
            FB_STATE_ENABLING           : DINT              := DINT#10;
            /// FB state: Waiting for request
            FB_STATE_WAIT_REQ           : DINT              := DINT#50;
            /// FB state: Sending SNTP telegram to client
            FB_STATE_SEND               : INT               := 51;
            /// FB state: Disabling
            FB_STATE_DISABLING          : DINT              := DINT#90;
            /// NTP telegram sent to client
            STATUS_TEL_SENT             : WORD              := WORD#16#0000;
            /// NTP request received from client
            STATUS_REQ_RECEIVED         : WORD              := WORD#16#0001;
            /// No job being currently processed
            STATUS_NO_CALL              : WORD              := WORD#16#7000;
            /// First call after incoming new job (rising edge 'enable')
            STATUS_FIRST_CALL           : WORD              := WORD#16#7001;
            /// Subsequent call during active processing without further details
            STATUS_SUBSEQUENT_CALL      : WORD              := WORD#16#7002;
            /// Disconnecting
            STATUS_DISCONNECTING        : WORD              := WORD#16#7003;
            /// Warning: Received packet doesn't match criteria and is ignored
            WARN_UNEXPECTED_PACKET      : WORD              := WORD#16#7F01;
            /// No error occured in subfunction call
            SUB_STATUS_NO_ERROR         : WORD              := WORD#16#0000;
            /// Error: due to an undefined state in state machine
            ERR_UNDEFINED_STATE         : WORD              := WORD#16#8600;
            /// Error: TCON ecountered error
            ERR_TCON                    : WORD              := WORD#16#8601;
            /// Error: TUSEND encountered error
            ERR_TUSEND                  : WORD              := WORD#16#8602;
            /// Error: TURCV encountered error
            ERR_TURCV                   : WORD              := WORD#16#8603;
        END_VAR

        tempEnable := enable; // Work with temporary value / create process image

        //
        // ENABLING/DISABLING
        //
        IF (tempEnable = TRUE) AND (statStatus = STATUS_NO_CALL) THEN // Enable FB
            // First call; initialize FB
            statValid                           := TRUE;
            statBusy                            := TRUE;
            statError                           := FALSE;
            statErrorUserCleared                := FALSE;
            statErrorAutoCleared                := FALSE;
            statStatus                          := STATUS_FIRST_CALL;
            statSubfunctionStatus               := SUB_STATUS_NO_ERROR;
            statFBErrorState                    := DINT#0;
            diagnostics                         := statEmptyDiagnostics;
            statDisablingCompleted              := FALSE;

            statConParam.InterfaceId            := hwID;
            statConParam.ConnectionID           := connID;
            statConParam.ConnectionType         := ConnectionType#Udp;
            statConParam.ActiveEstablished      := FALSE;
            statConParam.RemotePort             := UINT#0;
            statConParam.LocalPort              := UINT#123;

            // Clear send/receivce telegram buffer
            FOR tempIndex := 0 TO (LEN_SNTP - 1) DO
                statTelegramBuffer[tempIndex]   := BYTE#0;
            END_FOR;

            // Reset instructions
            instTCon(execute                    := FALSE,
                     connectionID               := statConParam.ConnectionID,
                     connectionConfiguration    := statConParam);

            instTURcv(enable                    := FALSE,
                      connectionID              := statConParam.ConnectionID,
                      rAddr                     := statAddr,
                      data                      := statTelegramBuffer);

            instTUSend(execute                  := FALSE,
                       connectionID             := statConParam.ConnectionID,
                       rAddr                    := statAddr,
                       data                     := statTelegramBuffer);

            instTDiscon(execute                 := FALSE,
                        connectionID            := statConParam.ConnectionID);

            // State machine - start functionality
            statFBState := FB_STATE_ENABLING;

        ELSIF (tempEnable = FALSE) AND (statEnableOld = TRUE) THEN // Disable FB
            statFBState := FB_STATE_DISABLING;

        ELSIF (statStatus = STATUS_FIRST_CALL) THEN // Set status identifier of subsequent call
            statStatus := STATUS_SUBSEQUENT_CALL;
        END_IF;

        // Edge detection 'enable' input
        statEnableOld := tempEnable;

        IF (statStatus = STATUS_NO_CALL) THEN // Nothing to do -> End here to reduce "system load"
            RETURN;
        END_IF;

        //
        // STATE_MACHINE
        //
        CASE statFBState OF // State machine of FB
            FB_STATE_NO_PROCESSING:
            // no processing
                // No processing active (Note: this state must always be present and left empty)
                ;

            FB_STATE_ENABLING: // Enabling active
            // enabling
            instTCon(execute                    := NOT instTCon.busy,
                     connectionID               := statConParam.ConnectionID,
                     connectionConfiguration    := statConParam);

                IF instTCon.done THEN
                    statFBState := FB_STATE_WAIT_REQ;
                ELSIF instTCon.error THEN
                    statStatus              := ERR_TCON;
                    statSubfunctionStatus   := instTCon.STATUS;
                    statFBErrorState        := statFBState;
                    statErrorUserCleared    := true;
                END_IF;

            FB_STATE_WAIT_REQ: // Processing active

                // waiting for request
                instTURcv(enable          := TRUE,
                          connectionID    := statConParam.ConnectionID,
                          rAddr           := statAddr,
                          data            := statTelegramBuffer);

                statStatus := STATUS_SUBSEQUENT_CALL;

                IF instTURcv.newDataReceived THEN
                    // Deserialize receive data
                    DeserializeBig(UDINT#0, statTelegramBuffer, statTelegramRcvd);

                    // Check received length and MODE (3 = Client)
                    IF (instTURcv.receivedLength = TO_UDINT(LEN_SNTP)) AND ((statTelegramRcvd.flags[0] AND MASK_MODE) = MODE_CLIENT) THEN
                        statStatus  := STATUS_REQ_RECEIVED;
                        statFBState := FB_STATE_SEND;
                    ELSE
                        statStatus  := WARN_UNEXPECTED_PACKET;
                    END_IF;
                ELSIF instTURcv.error THEN
                    statStatus              := ERR_TURCV;
                    statSubfunctionStatus   := instTURcv.STATUS;
                    statFBErrorState        := statFBState;
                    statErrorUserCleared    := TRUE;
                END_IF;

            FB_STATE_SEND:
            // sending response
                IF instTUSend.busy = FALSE THEN // Nothing sent yet
                    // Set NTP Data
                    statTelegramSend.rootDelay      := DWORD#0;
                    statTelegramSend.rootDispersion := DWORD#0;

                    // Read System Time
                    GetSystemDateTime(value => tempSysTime);

                    // Split System Time
                    SplitDateAndTime(
                        value       := tempSysTime,
                        year        => tempSysTimeYear);

                    // Asume invalid time if year < INVALID_YEAR
                    IF tempSysTimeYear < TO_INT(INVALID_YEAR) THEN
                        statTelegramSend.flags[1] := BYTE#0; // Stratum
                    ELSE
                        statTelegramSend.flags[1] := BYTE#1; // Stratum
                    END_IF;

                    // Convert System Time (UTC) to NTP Time
                    statTelegramSend.timestamps.receive                 := LSNTP_Time(tempSysTime);

                    // Set Reference Timestamp to actual time if no other information available
                    IF lastTimeSet <= LAST_TIME_SET_1990 THEN
                        statTelegramSend.timestamps.reference.sec       := statTelegramSend.timestamps.receive.sec;
                        statTelegramSend.timestamps.reference.secFrac   := statTelegramSend.timestamps.receive.secFrac;
                    ELSE
                        // Convert Reference Time (UTC) to NTP Time Format
                        statTelegramSend.timestamps.reference           := LSNTP_Time(lastTimeSet);
                    END_IF;

                    // Fill telegram according to RFC 4330
                    statTelegramSend.flags[0]       := MODE_SERVER;                 // Mode - No Warning, NTP Version 3, Server
                    statTelegramSend.flags[2]       := statTelegramRcvd.flags[2];   // Poll; Peer polling interval copied from request
                    statTelegramSend.flags[3]       := CLOCK_PRECISION;
                    statTelegramSend.rootDelay      := DWORD#0;                     // Root Delay
                    statTelegramSend.rootDispersion := DWORD#0;                     // Root Dispersion

                    // Set reference identifier according to RFC 4330, only LOCL, DCF and GPS supported
                    CASE referenceID OF
                        USINT#1:
                            statTelegramSend.referenceId[0] := 'D';
                            statTelegramSend.referenceId[1] := 'C';
                            statTelegramSend.referenceId[2] := 'F';
                            statTelegramSend.referenceId[3] := '$00';

                        USINT#2:
                            statTelegramSend.referenceId[0] := 'G';
                            statTelegramSend.referenceId[1] := 'P';
                            statTelegramSend.referenceId[2] := 'S';
                            statTelegramSend.referenceId[3] := '$00';

                        ELSE // Use LOCL if unsupported reference identifier is specified
                            statTelegramSend.referenceId[0] := 'L';
                            statTelegramSend.referenceId[1] := 'O';
                            statTelegramSend.referenceId[2] := 'C';
                            statTelegramSend.referenceId[3] := 'L';
                    END_CASE;

                    statTelegramSend.timestamps.transmit.sec        := statTelegramSend.timestamps.receive.sec;
                    statTelegramSend.timestamps.transmit.secFrac    := statTelegramSend.timestamps.receive.secFrac;

                    // Copy received originate Timestamp to Transmit Timestamp
                    statTelegramSend.timestamps.originate.sec       := statTelegramRcvd.timestamps.transmit.sec;
                    statTelegramSend.timestamps.originate.secFrac   := statTelegramRcvd.timestamps.transmit.secFrac;
                END_IF;

                // Serialize send data
                SerializeBig(UDINT#0, statTelegramSend, statTelegramBuffer);

                instTUSend(execute       := NOT instTUSend.busy,
                          connectionID   := statConParam.ConnectionID,
                          length         := TO_UDINT(LEN_SNTP), // send telegram without key identifier or authentication
                          data           := statTelegramBuffer,
                          rAddr          := statAddr);

                IF instTUSend.done OR instTUSend.error THEN
                    IF instTUSend.done THEN
                        statStatus := STATUS_TEL_SENT;
                    ELSE
                        statStatus              := ERR_TUSEND;
                        statSubfunctionStatus   := instTUSend.status;
                        statFBErrorState        := statFBState;
                        statErrorAutoCleared    := TRUE;
                    END_IF;

                    statFBState := FB_STATE_WAIT_REQ; // Wait for next request
                END_IF;

            FB_STATE_DISABLING: // Disabling active
                // disabling
                statStatus := STATUS_DISCONNECTING;

                instTDiscon(execute      := NOT instTDiscon.busy,
                            connectionID := statConParam.ConnectionID);

                IF instTDiscon.done OR instTDiscon.error THEN // Ignore TDISCON errors
                    statDisablingCompleted := TRUE;
                END_IF;

        ELSE // Undefined state in state machine reached
        // undefined state
            statStatus              := ERR_UNDEFINED_STATE;
            statErrorUserCleared    := TRUE;
        END_CASE;

        //
        // OUTPUTS
        //
        // Write outputs
        IF (statDisablingCompleted = TRUE) THEN
            // disabling
            // Reset outputs if disabling completed
            statValid                       := FALSE;
            statBusy                        := FALSE;
            statError                       := FALSE;
            statErrorUserCleared            := FALSE;
            statErrorAutoCleared            := FALSE;
            statStatus                      := STATUS_NO_CALL;

        ELSIF (statErrorUserCleared = TRUE) AND (statError = FALSE) THEN
            // error user cleared
            // Error can only be cleared by user; rising edge at enable input is needed to continue
            statValid                       := FALSE;
            statBusy                        := FALSE;
            statError                       := TRUE;
            // Write diagnostics
            diagnostics.status              := statStatus;
            diagnostics.subfunctionStatus   := statSubfunctionStatus;
            diagnostics.stateNumber         := statFBErrorState;
            // execution aborted --> set state no processing
            statFBState                     := FB_STATE_NO_PROCESSING;

        ELSIF (statErrorAutoCleared = TRUE) AND (statError = FALSE) THEN
            // error auto cleared
            // Error can be reset by FB automatically
            statValid                       := FALSE;
            statBusy                        := TRUE;
            statError                       := TRUE;
            // Write diagnostics
            diagnostics.status              := statStatus;
            diagnostics.subfunctionStatus   := statSubfunctionStatus;
            diagnostics.stateNumber         := statFBErrorState;
            // Nothing else to do, next state is set where error occured
            statErrorAutoCleared            := FALSE;

        ELSIF (statErrorAutoCleared = FALSE) AND (statErrorUserCleared = FALSE) AND (statError = TRUE) THEN
            // after user/auto cleared
            // If autocleared error is acknowledged
            statValid                       := TRUE;
            statBusy                        := TRUE;
            statError                       := FALSE;
            statStatus                      := STATUS_SUBSEQUENT_CALL;
        END_IF;

        //
        // Write static values to outputs
        //
        valid   := statValid;
        busy    := statBusy;
        error   := statError;
        status  := statStatus;

    END_FUNCTION_BLOCK

    /// Time in seconds since 1900-01-01-00:00:00
    FUNCTION LSNTP_Time : LSNTP_typeTimestamp

        VAR_INPUT
            /// Date and time that has to be converted to NTP time
            dateAndTime : LDATE_AND_TIME;
        END_VAR

        VAR_TEMP
            /// Actual day
            tempActDay          : INT;
            /// Actual month
            tempActMonth        : INT;
            /// Actual year
            tempActYear         : INT;
            /// Actual hour
            tempActHour         : INT;
            /// Actual minute
            tempActMinute       : INT;
            /// Actual second
            tempActSecond       : INT;
            /// Actual millisecond
            tempActMillisecond  : INT;
            /// Actual nanosecond
            tempActNanosecond   : INT;
            /// Total elapsed days
            tempElapsedDays     : UDINT;
            /// Total elapsed time in seconds
            tempElapsedTime     : UDINT;
            /// Temporary index for loops
            tempIndex           : DINT;
        END_VAR

        VAR CONSTANT
            /// 86400 seconds in 1 day
            SEC_PER_DAY         : UDINT     := UDINT#86400;
            /// Delta between 1970-1-1 and 1990-1-1 in seconds (IEC Time Base)
            DELTA_1970_1990     : UDINT     := UDINT#631152000;
            /// Delta between 1900-1-1 and 1970-1-1 in seconds
            DELTA_1900_1970     : UDINT     := UDINT#2208988800;
        END_VAR

        // Split System Time
        SplitDateAndTime(value      := dateAndTime,
                        year        => tempActYear,
                        month       => tempActMonth,
                        day         => tempActDay,
                        hour        => tempActHour,
                        minute      => tempActMinute,
                        second      => tempActSecond,
                        millisecond => tempActMillisecond,
                        nanoSecond  => tempActNanosecond);

        // Add number of days from full years, subtracting the current year
        FOR tempIndex := 1990 TO (tempActYear - 1) DO
            IF tempIndex MOD 4 = 0 AND tempIndex <> 2100 THEN
                tempElapsedDays := tempElapsedDays + UDINT#366;
            ELSE
                tempElapsedDays := tempElapsedDays + UDINT#365;
            END_IF;
        END_FOR;

        // Count has to start from 01-JAN
        tempElapsedDays := tempElapsedDays - UDINT#1;

        // Add days from full months of the current year
        IF tempActMonth > 1 THEN
            tempElapsedDays := tempElapsedDays + UDINT#31;
        END_IF;
        IF tempActMonth > 2 THEN
            IF tempActYear MOD 4 = 0 AND NOT (tempActYear = 2100) THEN
                tempElapsedDays := tempElapsedDays + UDINT#29;
            ELSE
                tempElapsedDays := tempElapsedDays + UDINT#28;
            END_IF;
        END_IF;
        IF tempActMonth > 3 THEN
            tempElapsedDays := tempElapsedDays + UDINT#31;
        END_IF;
        IF tempActMonth > 4 THEN
            tempElapsedDays := tempElapsedDays + UDINT#30;
        END_IF;
        IF tempActMonth > 5 THEN
            tempElapsedDays := tempElapsedDays + UDINT#31;
        END_IF;
        IF tempActMonth > 6 THEN
            tempElapsedDays := tempElapsedDays + UDINT#30;
        END_IF;
        IF tempActMonth > 7 THEN
            tempElapsedDays := tempElapsedDays + UDINT#31;
        END_IF;
        IF tempActMonth > 8 THEN
            tempElapsedDays := tempElapsedDays + UDINT#31;
        END_IF;
        IF tempActMonth > 9 THEN
            tempElapsedDays := tempElapsedDays + UDINT#30;
        END_IF;
        IF tempActMonth > 10 THEN
            tempElapsedDays := tempElapsedDays + UDINT#31;
        END_IF;
        IF tempActMonth > 11 THEN
            tempElapsedDays := tempElapsedDays + UDINT#30;
        END_IF;

        // Add days from current month
        tempElapsedDays := tempElapsedDays + TO_UDINT(tempActDay);
        // Elapsed time in seconds
        tempElapsedTime := (TO_UDINT(tempActMillisecond) / UDINT#1000) + TO_UDINT(tempActSecond) + (TO_UDINT(tempActMinute) * UDINT#60) + (TO_UDINT(tempActHour) * UDINT#60 * UDINT#60);

        LSNTP_Time.sec      := TO_DWORD((tempElapsedDays * SEC_PER_DAY) + tempElapsedTime + DELTA_1970_1990 + DELTA_1900_1970);
        LSNTP_Time.secFrac  := TO_DWORD(TO_UDINT(TO_LREAL(tempActNanosecond) * REAL#2.0 ** REAL#32.0 / REAL#10.0 ** REAL#9.0));

    END_FUNCTION

END_NAMESPACE