/// Writes an Ens.StreamContainer to a directory, named after the original file.
Class ConsentGate.BO.FileOut Extends Ens.BusinessOperation
{

Parameter SETTINGS = "FilePath:Basic,Prefix:Basic";

Property FilePath As %String;

Property Prefix As %String;

Method OnMessage(pRequest As Ens.StreamContainer, Output pResponse As Ens.Response) As %Status
{
    Set name = pRequest.Attributes.GetAt("Filename")
    If name = "" Set name = "message_" _ $ZDATE($HOROLOG, 8) _ "_" _ $JOB
    Set name = ..Prefix _ name
    Set name = $TRANSLATE(name, "/", "_")

    Set file = ##class(%Stream.FileCharacter).%New()
    Set file.Filename = ..FilePath _ "/" _ name

    Do pRequest.Stream.Rewind()
    While 'pRequest.Stream.AtEnd {
        Do file.Write(pRequest.Stream.Read(32000))
    }
    Set sc = file.%Save()
    If $$$ISERR(sc) Quit sc

    $$$LOGINFO("Wrote "_file.Filename)
    Quit $$$OK
}

}
