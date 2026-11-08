/// A free-text consent artefact: an authorisation letter, a revocation note,
/// a 42 CFR Part 2 consent form, or a court order. The agent reads these;
/// the deterministic gate only ever checks quotes against them.
Class ConsentGate.Data.ConsentDoc Extends %Persistent
{

Property MRN As %String(MAXLEN = 32) [ Required ];

/// AUTHORIZATION | REVOCATION | PART2_CONSENT | COURT_ORDER
Property DocType As %String(MAXLEN = 32);

Property ReceivedOn As %String(MAXLEN = 10);

Property Source As %String(MAXLEN = 128);

Property Body As %String(MAXLEN = 16384) [ Required ];

/// TEXT | EMBEDDED | OCR - where the text the gate verifies against came from
Property Provenance As %String(MAXLEN = 16);

/// Optional path to the scanned original, when the paper arrived as an image
Property ScanFile As %String(MAXLEN = 255);

Index MRNIdx On MRN;

ClassMethod ForMRN(mrn As %String) As %SQL.StatementResult
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT ID, DocType, ReceivedOn, Source, Body FROM ConsentGate_Data.ConsentDoc WHERE MRN = ? ORDER BY ReceivedOn")
    Quit stmt.%Execute(mrn)
}

}
