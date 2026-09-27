import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { marked } from 'marked'
import denikMd from '../../../docs/00-denik-vyvoje.md?raw'
import currentMd from '../../../docs/08-aktualni-verze.md?raw'
import { APP_VERSION } from '../lib/geo'

export default function Info() {
  const [showLegacy, setShowLegacy] = useState(false)
  const currentHtml = useMemo(() => marked.parse(currentMd) as string, [])
  const legacyHtml = useMemo(() => marked.parse(denikMd) as string, [])

  return (
    <div className="info">
      <div className="info-head">
        <Link className="ghost" to="/">← zpět</Link>
        <span className="muted">{APP_VERSION}</span>
      </div>
      <div className="info-body">
        <img src="/logo.gif" alt="KSMF Snake" className="info-logo" />
        <h1>KSMF Snake</h1>
        <p className="credits">Vyrobil <b>ChatGPT</b> &amp; <b>WakeDown</b> · <a href="mailto:wakedown@matfyz.cz">wakedown@matfyz.cz</a></p>
        <p className="muted">Lokační hra v reálném městě — had na ulicích. Aktuální pravidla, výchozí nastavení a technický stav jsou uvedené níže.</p>
        <hr />
        <div className="markdown" dangerouslySetInnerHTML={{ __html: currentHtml }} />
        <hr />
        <button className="ghost" onClick={() => setShowLegacy((value) => !value)}>
          {showLegacy ? 'Skrýt historii původní hry' : 'Zobrazit historii původní hry AchtungDieKM'}
        </button>
        {showLegacy && <div className="markdown" dangerouslySetInnerHTML={{ __html: legacyHtml }} />}
      </div>
    </div>
  )
}
