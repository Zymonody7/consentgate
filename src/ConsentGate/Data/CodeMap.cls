/// Maps an observation LOINC code to the consent category it belongs to.
/// This map is what turns "which OBX segments may leave the building" into
/// a policy question rather than a coding question.
Class ConsentGate.Data.CodeMap Extends %Persistent
{

Property Code As %String(MAXLEN = 20) [ Required ];

Property Display As %String(MAXLEN = 128);

/// GENERAL | SUBSTANCE_USE | MENTAL_HEALTH | HIV | GENETIC
Property Category As %String(MAXLEN = 32);

Index CodeIdx On Code [ Unique ];

ClassMethod CategoryOf(code As %String) As %String
{
    Set obj = ##class(ConsentGate.Data.CodeMap).CodeIdxOpen(code)
    If '$IsObject(obj) Quit "GENERAL"
    Quit obj.Category
}

}
