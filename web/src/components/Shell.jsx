import { useEffect, useState } from 'react'
import { NavLink, useLocation } from 'react-router-dom'
import {
  LayoutDashboard,
  ListChecks,
  FileText,
  ScanText,
  BookOpen,
  ShieldCheck,
  Moon,
  Sun,
} from 'lucide-react'
import { cn } from '../lib/utils'
import { useDecisions, useJson } from '../lib/data'

const NAV = [
  { to: '/', label: 'Overview', icon: LayoutDashboard, end: true },
  { to: '/queue', label: 'Queue', icon: ListChecks },
  { to: '/documents', label: 'Consent documents', icon: FileText },
  { to: '/reader', label: 'Message reader', icon: ScanText },
  { to: '/rules', label: 'Gate rules', icon: BookOpen },
]

const TITLES = {
  '/': 'Overview',
  '/queue': 'Disclosure queue',
  '/documents': 'Consent documents',
  '/reader': 'Message reader',
  '/rules': 'Gate rules',
}

function useTheme() {
  const [dark, setDark] = useState(() => {
    const saved = localStorage.getItem('cg-theme')
    if (saved) return saved === 'dark'
    return window.matchMedia('(prefers-color-scheme: dark)').matches
  })
  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark)
    localStorage.setItem('cg-theme', dark ? 'dark' : 'light')
  }, [dark])
  return [dark, setDark]
}

export default function Shell({ children }) {
  const [dark, setDark] = useTheme()
  const location = useLocation()
  const { decisions } = useDecisions()
  const { data: stats } = useJson('data/stats.json', null)
  const title = TITLES[location.pathname] || (location.pathname.startsWith('/decision') ? 'Decision' : 'ConsentGate')
  const model = decisions[0]?.model || '—'

  return (
    <div className="flex h-full">
      <aside className="hidden w-52 shrink-0 flex-col border-r border-border bg-card md:flex">
        <div className="flex items-center gap-2.5 px-5 pb-4 pt-5">
          <ShieldCheck className="h-5 w-5" />
          <div>
            <div className="text-sm font-semibold leading-tight">ConsentGate</div>
            <div className="text-[10.5px] uppercase tracking-[0.09em] text-muted-foreground">Disclosure review</div>
          </div>
        </div>

        <nav className="flex flex-col gap-0.5 px-2">
          {NAV.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2.5 rounded px-2.5 py-1.5 text-[12.5px] text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground',
                  isActive && 'bg-accent font-medium text-accent-foreground',
                )
              }
            >
              <Icon className="h-4 w-4" />
              {label}
              {to === '/queue' && <span className="ml-auto text-[11px] tnum">{stats?.total ?? ''}</span>}
            </NavLink>
          ))}
        </nav>

        <div className="mt-auto border-t border-border px-5 py-4 text-[11.5px] text-muted-foreground">
          <div className="flex justify-between gap-3">
            <span>Model</span>
            <span className="truncate font-mono text-foreground">{model}</span>
          </div>
          <div className="mt-1 flex justify-between gap-3">
            <span>Snapshot</span>
            <span className="font-mono">{stats ? 'live' : '—'}</span>
          </div>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex h-12 shrink-0 items-center gap-3 border-b border-border bg-card px-5">
          <h1 className="text-[15px] font-medium">{title}</h1>
          <div className="ml-auto flex items-center gap-2">
            <button
              onClick={() => setDark(!dark)}
              className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-accent hover:text-accent-foreground"
              aria-label="Toggle theme"
            >
              {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </button>
          </div>
        </header>

        <nav className="flex gap-1 overflow-x-auto border-b border-border bg-card px-3 py-2 md:hidden">
          {NAV.map(({ to, label, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                cn(
                  'whitespace-nowrap rounded-md px-2.5 py-1 text-xs text-muted-foreground',
                  isActive && 'bg-accent font-medium text-accent-foreground',
                )
              }
            >
              {label}
            </NavLink>
          ))}
        </nav>

        <main className="min-h-0 flex-1 overflow-y-auto">{children}</main>
      </div>
    </div>
  )
}
