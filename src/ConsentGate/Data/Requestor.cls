/// A downstream consumer asking for data, and why.
Class ConsentGate.Data.Requestor Extends %Persistent
{

Property OrgId As %String(MAXLEN = 64) [ Required ];

Property OrgName As %String(MAXLEN = 128);

/// TREATMENT | PAYMENT | OPERATIONS | RESEARCH | PUBLIC_HEALTH
Property PurposeOfUse As %String(MAXLEN = 32);

Property Notes As %String(MAXLEN = 1024);

Index OrgIdx On OrgId [ Unique ];

ClassMethod ByOrg(orgId As %String) As ConsentGate.Data.Requestor
{
    Quit ##class(ConsentGate.Data.Requestor).OrgIdxOpen(orgId)
}

}
