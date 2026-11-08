#!/usr/bin/env bash
# Prints the property/setting names of the Interoperability classes we configure
# in Production.cls, so the XML can be corrected against the real image.
set -u
NS=CONSENTGATE

docker compose exec -T iris iris session IRIS -U $NS <<'EOF'
Do ..Props("EnsLib.HL7.Service.FileService")
Do ..Props("EnsLib.HL7.Operation.FileOperation")
halt

Props(cls) Public
{
    Set cd = ##class(%Dictionary.ClassDefinition).%OpenId(cls)
    If '$IsObject(cd) Write "MISSING ", cls, ! Quit
    Write "== ", cls, " ==", !
    Do ..Walk(cd)
}
Walk(cd)
{
    Set props = cd.Properties
    For i = 1:1:props.Count() {
        Set p = props.GetAt(i)
        Write "  ", p.Name, " : ", p.Type, !
    }
    For i = 1:1:cd.Super.Count() {
        Set sup = cd.Super.GetAt(i)
        Set scd = ##class(%Dictionary.ClassDefinition).%OpenId(sup)
        If $IsObject(scd) Do ..Walk(scd)
    }
}
EOF
