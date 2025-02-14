// This is generated code. *** DO NOT MODIFY ***

NAMESPACE Simatic.Ax.sntp
FUNCTION SerializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
    END_VAR
    VAR_IN_OUT
        value : LSNTP_typeTelegram;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_TEMP
        i : DINT;
    END_VAR
    SerializeBig := offset;
    FOR i := DINT#0 TO DINT#3 DO
        SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.flags[i], buffer := buffer);
    END_FOR;
    SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.rootDelay, buffer := buffer);
    SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.rootDispersion, buffer := buffer);
    FOR i := DINT#0 TO DINT#3 DO
        SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.referenceId[i], buffer := buffer);
    END_FOR;
    SerializeBig := SerializeBig(offset := SerializeBig, value := value.timestamps, buffer := buffer);
END_FUNCTION

FUNCTION DeserializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_IN_OUT
        value : LSNTP_typeTelegram;
    END_VAR
    VAR_TEMP
        i : DINT;
    END_VAR
    DeserializeBig := offset;
    FOR i := DINT#0 TO DINT#3 DO
        DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.flags[i], buffer := buffer);
    END_FOR;
    DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.rootDelay, buffer := buffer);
    DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.rootDispersion, buffer := buffer);
    FOR i := DINT#0 TO DINT#3 DO
        DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.referenceId[i], buffer := buffer);
    END_FOR;
    DeserializeBig := DeserializeBig(offset := DeserializeBig, value := value.timestamps, buffer := buffer);
END_FUNCTION
END_NAMESPACE
