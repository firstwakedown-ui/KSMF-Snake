import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { marked } from 'marked'
import denikMd from '../../../docs/00-denik-vyvoje.md?raw'
import { APP_VERSION } from '../lib/geo'

export default function Info() {
  const html = useMemo(() => marked.parse(denikMd) as string, [])

  return (
    <div className="info">
      <div className="info-head">
        <Link className="ghost" to="/">← zpět</Link>
        <span className="muted">{APP_VERSION}</span>
      </div>
      <div className="info-body">
        <img src="/logo.gif" alt="AchtungDieKM" className="info-logo" />
        <h1>AchtungDieKM</h1>
        <p className="credits">Vyrobil <b>Claude Code</b> &amp; <b>WakeDown</b> · <a href="mailto:wakedown@matfyz.cz">wakedown@matfyz.cz</a></p>
        <p className="muted">Lokační hra v reálném městě — had na ulicích. Níže je <b>deník vývoje</b>: jak hra vznikala krok za krokem.</p>
        <hr />
        <div className="markdown" dangerouslySetInnerHTML={{ __html: html }} />
      </div>
    </div>
  )
}
