Class ConsentGate.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="ConsentGate.Production" LogGeneralTraceEvents="false">
  <Description>Consent-aware HL7 disclosure gate: file in, agent reviews, gate decides, file out.</Description>
  <ActorPoolSize>2</ActorPoolSize>

  <Item Name="In" Category="" ClassName="EnsLib.File.PassthroughService" PoolSize="1" Enabled="true" Foreground="false" Comment="Watches data/in for HL7 files" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/home/irisowner/dev/data/in</Setting>
    <Setting Target="Adapter" Name="FileSpec">*.hl7</Setting>
    <Setting Target="Adapter" Name="WorkPath">/home/irisowner/dev/data/work</Setting>
    <Setting Target="Host" Name="TargetConfigNames">Disclosure</Setting>
  </Item>

  <Item Name="Disclosure" Category="" ClassName="ConsentGate.BP.Disclosure" PoolSize="2" Enabled="true" Foreground="false" Comment="Agent review plus deterministic gate" LogTraceEvents="false" Schedule="" />

  <Item Name="Archive" Category="" ClassName="ConsentGate.BO.FileOut" PoolSize="1" Enabled="true" Foreground="false" Comment="Released or redacted message" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="FilePath">/home/irisowner/dev/data/out</Setting>
    <Setting Target="Host" Name="Prefix">released_</Setting>
  </Item>

  <Item Name="Escalate" Category="" ClassName="ConsentGate.BO.FileOut" PoolSize="1" Enabled="true" Foreground="false" Comment="Held for human review" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="FilePath">/home/irisowner/dev/data/out/escalated</Setting>
    <Setting Target="Host" Name="Prefix">escalated_</Setting>
  </Item>

  <Item Name="Deny" Category="" ClassName="ConsentGate.BO.FileOut" PoolSize="1" Enabled="true" Foreground="false" Comment="Refused disclosure" LogTraceEvents="false" Schedule="">
    <Setting Target="Host" Name="FilePath">/home/irisowner/dev/data/out/denied</Setting>
    <Setting Target="Host" Name="Prefix">denied_</Setting>
  </Item>
</Production>
}

}
