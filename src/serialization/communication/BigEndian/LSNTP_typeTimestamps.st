// This is generated code. *** DO NOT MODIFY ***

NAMESPACE Simatic.Ax.sntp
FUNCTION SerializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
    END_VAR
    VAR_IN_OUT
        value : LSNTP_typeTimestamps;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    SerializeBig := offset;
    SerializeBig := SerializeBig(offset := SerializeBig, value := value.reference, buffer := buffer);
    SerializeBig := SerializeBig(offset := SerializeBig, value := value.originate, buffer := buffer);
    SerializeBig := SerializeBig(offset := SerializeBig, value := value.receive, buffer := buffer);
    SerializeBig := SerializeBig(offset := SerializeBig, value := value.transmit, buffer := buffer);
END_FUNCTION

FUNCTION DeserializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_IN_OUT
        value : LSNTP_typeTimestamps;
    END_VAR
    DeserializeBig := offset;
    DeserializeBig := DeserializeBig(offset := DeserializeBig, value := value.reference, buffer := buffer);
    DeserializeBig := DeserializeBig(offset := DeserializeBig, value := value.originate, buffer := buffer);
    DeserializeBig := DeserializeBig(offset := DeserializeBig, value := value.receive, buffer := buffer);
    DeserializeBig := DeserializeBig(offset := DeserializeBig, value := value.transmit, buffer := buffer);
END_FUNCTION
END_NAMESPACE
