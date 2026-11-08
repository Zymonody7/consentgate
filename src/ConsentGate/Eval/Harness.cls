/// Reproducible evaluation of the decision layer, independent of any model.
///
/// Each case in eval/cases.json is a consent situation with a ground-truth
/// disposition and one model output - some honest, some adversarial. The
/// harness feeds those outputs straight into the policy gate and reports
/// whether the final disposition matches the ground truth.
///
/// Run:  do ##class(ConsentGate.Eval.Harness).Run()
Class ConsentGate.Eval.Harness Extends %RegisteredObject
{

ClassMethod Run(path As %String = "/home/irisowner/dev/eval/cases.json") As %Status
{
    Set f = ##class(%Stream.FileCharacter).%New()
    Set f.Filename = path
    Set json = f.Read()
    Set cases = ##class(%DynamicArray).%FromJSON(json)

    Set total = 0, decisionOk = 0, withheldOk = 0
    Write "id    decision          withheld                   result", !
    Write $Translate($Justify("", 68), " ", "-"), !

    Set i = 0
    While i < cases.%Size() {
        Set c = cases.%Get(i)
        Set total = total + 1
        Set mrn = c.mrn
        Set requestor = c.%Get("requestor")
        If requestor = "" Set requestor = "ORG-CLINIC"

        // Resolve docRef strings to the actual document ids in this database.
        Set findings = ##class(%DynamicArray).%New()
        Set src = c.findings
        Set j = 0
        While j < src.%Size() {
            Set s = src.%Get(j)
            Set ref = s.docRef
            Set docType = $PIECE(ref, ":", 2)
            Set contains = $PIECE(ref, ":", 3, 99)
            Set docId = ##class(ConsentGate.BP.Disclosure).DocId(mrn, docType, contains)
            Do findings.%Push({
                "docId": (docId),
                "category": (s.category),
                "effect": (s.effect),
                "recipient": (s.%Get("recipient")),
                "validUntil": (s.%Get("validUntil")),
                "quote": (s.quote)
            })
            Set j = j + 1
        }

        Set agentRaw = {"findings": (findings), "rationale": "harness", "confidence": 0.9}.%ToJSON()
        Set verdict = ##class(ConsentGate.Policy.Gate).Apply(mrn, requestor, c.categories, agentRaw)

        Set dOk = (verdict.decision = c.expectDecision)
        Set wOk = ..SameSet(verdict.withhold, c.expectWithheld)
        If dOk Set decisionOk = decisionOk + 1
        If dOk && wOk Set withheldOk = withheldOk + 1

        Write $Justify(c.id, 6), " ", $Justify(verdict.decision, 8), "/", $Justify(c.expectDecision, 8), "  "
        Write $Justify(verdict.withhold.%ToJSON(), 24), " "
        If dOk && wOk {
            Write "PASS  ", c.label
        } Else {
            Write "FAIL  ", c.label
            Write "   gate=", verdict.gate
            If verdict.notes.%Size() > 0 Write "  notes=", verdict.notes.%ToJSON()
        }
        Write !
        Set i = i + 1
    }

    Write !
    Write "cases=", total, "  decision match=", decisionOk, "  disposition+scope match=", withheldOk, !
    Write "This measures the gate's handling of given model outputs, not the model itself.", !
    Quit $$$OK
}

ClassMethod SameSet(a As %DynamicArray, b As %DynamicArray) As %Boolean
{
    If a.%Size() '= b.%Size() Quit 0
    Set i = 0, ok = 1
    While i < b.%Size() {
        If '##class(ConsentGate.Policy.Gate).InArray(a, b.%Get(i)) Set ok = 0
        Set i = i + 1
    }
    Quit ok
}

}
