import { cn } from '../../lib/utils'

export function Card({ className, ...props }) {
  return <div className={cn('rounded-md border border-border bg-card text-card-foreground', className)} {...props} />
}
export function CardHeader({ className, ...props }) {
  return <div className={cn('flex flex-col gap-1 p-5', className)} {...props} />
}
export function CardTitle({ className, ...props }) {
  return <div className={cn('text-sm font-medium text-muted-foreground', className)} {...props} />
}
export function CardContent({ className, ...props }) {
  return <div className={cn('p-5 pt-0', className)} {...props} />
}
