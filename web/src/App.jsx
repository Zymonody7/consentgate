import { Routes, Route } from 'react-router-dom'
import { TooltipProvider } from './components/ui/tooltip'
import Shell from './components/Shell'
import Overview from './pages/Overview'
import Queue from './pages/Queue'
import Decision from './pages/Decision'
import Documents from './pages/Documents'
import Reader from './pages/Reader'
import Rules from './pages/Rules'

export default function App() {
  return (
    <TooltipProvider delayDuration={200}>
      <Shell>
        <Routes>
          <Route path="/" element={<Overview />} />
          <Route path="/queue" element={<Queue />} />
          <Route path="/decision/:id" element={<Decision />} />
          <Route path="/documents" element={<Documents />} />
          <Route path="/reader" element={<Reader />} />
          <Route path="/rules" element={<Rules />} />
          <Route path="*" element={<Overview />} />
        </Routes>
      </Shell>
    </TooltipProvider>
  )
}
