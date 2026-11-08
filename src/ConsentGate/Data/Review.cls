/// A reviewer decision on an escalated disclosure. One row per action.
/// Kept beside the decision row rather than overwriting it so the audit
/// trail remains append-only: the gate result changes, the history does not.
Class ConsentGate.Data.Review Extends %Persistent
{

Property DecisionId As %Integer;

/// APPROVE | UPHOLD
Property Action As %String(MAXLEN = 16, VALUELIST = ",APPROVE,UPHOLD");

Property Reviewer As %String(MAXLEN = 64);

Property Note As %String(MAXLEN = 512);

Property CreatedAt As %String(MAXLEN = 32);

Index DecisionIdx On DecisionId;

Index CreatedIdx On CreatedAt;

}
