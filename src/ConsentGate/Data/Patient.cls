/// A patient known to the consent gate. Synthetic data only.
Class ConsentGate.Data.Patient Extends %Persistent
{

Property MRN As %String(MAXLEN = 32) [ Required ];

Property FamilyName As %String(MAXLEN = 80);

Property GivenName As %String(MAXLEN = 80);

Property DOB As %String(MAXLEN = 10);

Index MRNIdx On MRN [ Unique ];

ClassMethod ByMRN(mrn As %String) As ConsentGate.Data.Patient
{
    Quit ##class(ConsentGate.Data.Patient).MRNIdxOpen(mrn)
}

}
