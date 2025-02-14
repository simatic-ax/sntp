NAMESPACE Simatic.Ax.sntp

    TYPE

        /// Provides a structure for detailed diagnostics
        typeDiagnostics : STRUCT
            /// Status of the block or error identification when error occurred
            status              : WORD      := WORD#0;
            /// Status or return value of called FBs, FCs and system blocks
            subfunctionStatus   : DWORD     := DWORD#0;
            /// State in the state machine of the block where the error occurred
            stateNumber         : DINT      := DINT#0;
        END_STRUCT;

        LSNTP_typeTelegram : STRUCT
            /// Leap inidcator, version, mode, stratum, poll, precision
            flags               : ARRAY[0..3] OF BYTE;
            /// Indicates the total round trip delay to the primary reference source in seconds
            rootDelay           : DWORD;
            /// Indicates the maximum error due to the clock frequency tolerance
            rootDispersion      : DWORD;
            /// Identifies the clock reference source
            referenceId         : ARRAY[0..3] OF CHAR;
            /// Timestamps
            timestamps          : LSNTP_typeTimestamps;
            // /// (Optional) Contains the message authentication code if authentication scheme is implemented
            // keyIdentifier       : DWORD;
            // /// (Optional) Contains the message authentication code if authentication scheme is implemented
            // messageDigest       : ARRAY[0..15] OF BYTE;
        END_STRUCT;

        LSNTP_typeTimestamps : STRUCT
            /// Time when the system clock was last set or corrected
            reference           : LSNTP_typeTimestamp;
            /// Time when the request departed the client
            originate           : LSNTP_typeTimestamp;
            /// Time when the request departed the client
            receive             : LSNTP_typeTimestamp;
            /// Time when the reply departed the server
            transmit            : LSNTP_typeTimestamp;
        END_STRUCT;

        LSNTP_typeTimestamp : STRUCT
            /// Time in seconds since 1900-01-01-00:00:00
            sec                 : DWORD     := DWORD#0;
            /// Fraction of the current second
            secFrac             : DWORD     := DWORD#0;
        END_STRUCT;

    END_TYPE
END_NAMESPACE