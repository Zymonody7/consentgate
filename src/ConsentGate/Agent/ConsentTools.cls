/// Read-only tools handed to the consent agent. Every tool returns JSON.
/// Nothing here can write, disclose or mutate - the agent can only look.
Class ConsentGate.Agent.ConsentTools Extends %AI.ToolSet
{

XData Definition [ MimeType = application/xml ]
{
<ToolSet Name="ConsentTools">
<Description>Read-only access to a patient's consent artefacts and to the profile of the organisation requesting data.</Description>

<Tool Name="GetConsentDocuments" Method="GetConsentDocuments">
<Description>Return every consent artefact on file for a patient: authorisation letters, revocations, 42 CFR Part 2 consents and court orders. Each item has docId, docType, receivedOn and the full body text. Always read these before deciding.</Description>
</Tool>

<Tool Name="GetStructuredConsents" Method="GetStructuredConsents">
<Description>Return machine-readable consent rows for a patient: category (GENERAL, SUBSTANCE_USE, MENTAL_HEALTH, HIV, GENETIC), status (GRANTED or DENIED) and the validity window. This is the structured view; the free-text documents may qualify it.</Description>
</Tool>

<Tool Name="GetRequestorProfile" Method="GetRequestorProfile">
<Description>Return the requesting organisation's name, declared purpose of use and any notes. Use it to judge whether the disclosure purpose is consistent with what the patient authorised.</Description>
</Tool>

</ToolSet>
}

ClassMethod GetConsentDocuments(mrn As %String) As %String
{
    Set out = []
    Set rs = ##class(ConsentGate.Data.ConsentDoc).ForMRN(mrn)
    While rs.%Next() {
        Do out.%Push({
            "docId": (rs.ID),
            "docType": (rs.DocType),
            "receivedOn": (rs.ReceivedOn),
            "source": (rs.Source),
            "body": (##class(ConsentGate.Policy.Untrusted).Frame(rs.Body))
        })
    }
    Quit out.%ToJSON()
}

ClassMethod GetStructuredConsents(mrn As %String) As %String
{
    Set out = []
    Set rs = ##class(ConsentGate.Data.StructuredConsent).ForMRN(mrn)
    While rs.%Next() {
        Do out.%Push({
            "category": (rs.Category),
            "status": (rs.Status),
            "validFrom": (rs.ValidFrom),
            "validTo": (rs.ValidTo)
        })
    }
    Quit out.%ToJSON()
}

ClassMethod GetRequestorProfile(orgId As %String) As %String
{
    Set r = ##class(ConsentGate.Data.Requestor).ByOrg(orgId)
    If '$IsObject(r) Quit "{""error"": ""unknown requestor""}"
    Quit {
        "orgId": (r.OrgId),
        "orgName": (r.OrgName),
        "purposeOfUse": (r.PurposeOfUse),
        "notes": (r.Notes)
    }.%ToJSON()
}

}
