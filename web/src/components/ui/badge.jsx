import { cn } from '../../lib/utils'

const styles = {
  release: 'bg-release-bg text-release',
  redact: 'bg-redact-bg text-redact',
  deny: 'bg-deny-bg text-deny',
  escalate: 'bg-escalate-bg text-escalate',
  untrusted: 'border border-dashed border-muted-foreground/50 text-muted-foreground',
  outline: 'border border-border text-muted-foreground',
}

export function Badge({ kind = 'outline', className, children, ...props }) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-[0.06em]',
        styles[kind],
        className,
      )}
      {...props}
    >
      {children}
    </span>
  )
}

export function DecisionBadge({ decision }) {
  const k = String(decision || '').toLowerCase()
  return <Badge kind={styles[k] ? k : 'outline'}>{decision}</Badge>
}
