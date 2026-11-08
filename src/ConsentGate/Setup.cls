/// Seeds synthetic patients, consent artefacts, requestors and the
/// LOINC-to-category map, then starts the Interoperability production.
/// No real patient data is used anywhere in this project.
Class ConsentGate.Setup Extends %RegisteredObject
{

ClassMethod Seed() As %Status
{
    Set sc = $$$OK
    Set tSC = ..Reset()
    If $$$ISERR(tSC) Quit tSC

    // --- Patients -------------------------------------------------------
    Do ..Patient("CG-0001", "Alvarez", "Maria", "1971-04-12")
    Do ..Patient("CG-0002", "Chen", "David", "1985-11-02")
    Do ..Patient("CG-0003", "Bello", "Aisha", "1990-06-27")
    Do ..Patient("CG-0004", "Wright", "Thomas", "1963-02-19")
    Do ..Patient("CG-0005", "Park", "Lena", "1998-09-30")

    // --- Requestors -----------------------------------------------------
    Do ..Requestor("ORG-CLINIC", "St. Elsewhere Community Clinic", "TREATMENT", "Continuity-of-care referral from primary care.")
    Do ..Requestor("ORG-REGISTRY", "State Public Health Registry", "PUBLIC_HEALTH", "Mandated notifiable-condition surveillance.")
    Do ..Requestor("ORG-PAYER", "Northwind Health Plan", "PAYMENT", "Claims adjudication.")

    // --- LOINC to consent category -------------------------------------
    Do ..Code("4548-4", "Hemoglobin A1c", "GENERAL")
    Do ..Code("2160-0", "Creatinine", "GENERAL")
    Do ..Code("1975-2", "Bilirubin, total", "GENERAL")
    Do ..Code("9459-0", "Ethyl glucuronide, urine", "SUBSTANCE_USE")
    Do ..Code("19270-4", "Drug screen panel, urine", "SUBSTANCE_USE")
    Do ..Code("72166-2", "PHQ-9 total score", "MENTAL_HEALTH")
    Do ..Code("44249-1", "PHQ-9 item", "MENTAL_HEALTH")
    Do ..Code("24467-3", "CD4 count", "HIV")
    Do ..Code("75622-1", "HIV-1 RNA viral load", "HIV")
    Do ..Code("21667-1", "BRCA1 pathogenic variant", "GENETIC")

    // --- Consent artefacts ----------------------------------------------
    // CG-0001: broad treatment authorisation, explicitly excludes substance use.
    Do ..Doc("CG-0001", "AUTHORIZATION", "2026-10-02", "scan-alvarez-auth.pdf",
        "AUTHORIZATION FOR RELEASE OF PROTECTED HEALTH INFORMATION. Patient Maria Alvarez authorizes St. Elsewhere Community Clinic to receive laboratory results related to diabetes and kidney function for the purpose of continuing care. This authorization does not extend to records of substance use disorder treatment, which are not authorised for release under this form. Effective 2026-10-02, expires 2027-10-02.")

    // CG-0002: authorisation, then a revocation nine days later.
    Do ..Doc("CG-0002", "AUTHORIZATION", "2026-09-14", "scan-chen-auth.pdf",
        "AUTHORIZATION FOR RELEASE OF PROTECTED HEALTH INFORMATION. Patient David Chen authorizes release of laboratory results to St. Elsewhere Community Clinic for treatment purposes. Effective 2026-09-14, expires 2027-09-14.")
    Do ..Doc("CG-0002", "REVOCATION", "2026-10-28", "letter-chen-revocation.pdf",
        "Please be advised that I, David Chen, revoke the authorization I signed on 2026-09-14. No further disclosures are permitted except where required by law for emergency treatment. This revocation takes effect immediately on receipt.")

    // CG-0003: 42 CFR Part 2 consent, recipient-limited, plus an HIV denial.
    Do ..Doc("CG-0003", "PART2_CONSENT", "2026-08-30", "form-bello-part2.pdf",
        "CONSENT FOR DISCLOSURE OF SUBSTANCE USE DISORDER RECORDS UNDER 42 CFR PART 2. Patient Aisha Bello consents to disclosure of substance use disorder treatment records to St. Elsewhere Community Clinic only. Redisclosure by the recipient is prohibited. This consent expires 2027-08-30 or upon revocation.")
    Do ..Doc("CG-0003", "AUTHORIZATION", "2026-08-30", "form-bello-hiv.pdf",
        "Patient Aisha Bello has declined, in writing, the release of HIV-related laboratory results to any party other than her treating physician.")

    // CG-0004: court order compelling release of genetic results.
    Do ..Doc("CG-0004", "COURT_ORDER", "2026-10-15", "order-wright-2026-CV-8841.pdf",
        "IN THE MATTER OF WRIGHT. The court orders the custodian to disclose the patient's BRCA1 genetic test result to the State Public Health Registry. Disclosure is limited to the single genetic finding described in the petition and to no other records.")

    // CG-0005: authorisation that expired before the request.
    Do ..Doc("CG-0005", "AUTHORIZATION", "2024-01-10", "scan-park-auth.pdf",
        "AUTHORIZATION FOR RELEASE OF PROTECTED HEALTH INFORMATION. Patient Lena Park authorizes release of laboratory results to St. Elsewhere Community Clinic for treatment purposes. This authorization expires on 2025-01-10.")

    // --- Structured consent rows ----------------------------------------
    Do ..Consent("CG-0001", "GENERAL", "GRANTED", "2026-10-02", "2027-10-02")
    Do ..Consent("CG-0001", "SUBSTANCE_USE", "DENIED", "2026-10-02", "2027-10-02")
    Do ..Consent("CG-0003", "SUBSTANCE_USE", "GRANTED", "2026-08-30", "2027-08-30")
    Do ..Consent("CG-0003", "HIV", "DENIED", "2026-08-30", "2027-08-30")
    Do ..Consent("CG-0004", "GENETIC", "GRANTED", "2026-10-15", "2027-10-15")

    Quit sc
}

ClassMethod Reset() As %Status
{
    Set tSC = $$$OK
    Do ##class(ConsentGate.Data.Patient).%KillExtent()
    Do ##class(ConsentGate.Data.ConsentDoc).%KillExtent()
    Do ##class(ConsentGate.Data.StructuredConsent).%KillExtent()
    Do ##class(ConsentGate.Data.Requestor).%KillExtent()
    Do ##class(ConsentGate.Data.CodeMap).%KillExtent()
    Do ##class(ConsentGate.Data.Decision).%KillExtent()
    Quit tSC
}

ClassMethod Patient(mrn As %String, family As %String, given As %String, dob As %String) As %Status
{
    Set p = ##class(ConsentGate.Data.Patient).%New()
    Set p.MRN = mrn
    Set p.FamilyName = family
    Set p.GivenName = given
    Set p.DOB = dob
    Quit p.%Save()
}

ClassMethod Requestor(orgId As %String, name As %String, purpose As %String, notes As %String) As %Status
{
    Set r = ##class(ConsentGate.Data.Requestor).%New()
    Set r.OrgId = orgId
    Set r.OrgName = name
    Set r.PurposeOfUse = purpose
    Set r.Notes = notes
    Quit r.%Save()
}

ClassMethod Code(code As %String, display As %String, category As %String) As %Status
{
    Set c = ##class(ConsentGate.Data.CodeMap).%New()
    Set c.Code = code
    Set c.Display = display
    Set c.Category = category
    Quit c.%Save()
}

ClassMethod Doc(mrn As %String, docType As %String, receivedOn As %String, source As %String, body As %String) As %Status
{
    Set d = ##class(ConsentGate.Data.ConsentDoc).%New()
    Set d.MRN = mrn
    Set d.DocType = docType
    Set d.ReceivedOn = receivedOn
    Set d.Source = source
    Set d.Body = body
    Quit d.%Save()
}

ClassMethod Consent(mrn As %String, category As %String, status As %String, validFrom As %String, validTo As %String) As %Status
{
    Set c = ##class(ConsentGate.Data.StructuredConsent).%New()
    Set c.MRN = mrn
    Set c.Category = category
    Set c.Status = status
    Set c.ValidFrom = validFrom
    Set c.ValidTo = validTo
    Quit c.%Save()
}

ClassMethod StartProduction() As %Status
{
    Set sc = ##class(Ens.Director).StartProduction("ConsentGate.Production")
    Quit sc
}

}
