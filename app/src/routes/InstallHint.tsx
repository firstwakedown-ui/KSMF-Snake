import { useEffect, useState } from 'react'

// Nabídka instalace PWA na plochu.
// - Když prohlížeč vyvolá beforeinstallprompt (zachyceno globálně v main.tsx) → nativní prompt.
// - Když ne (Brave/Firefox, iOS Safari, nebo Chrome před splněním heuristiky) → ruční návod.
// Tlačítko je proto vidět VŽDY (dokud appka neběží jako standalone / dokud ho uživatel nezavře).
export default function InstallHint() {
  const [deferred, setDeferred] = useState<any>(() => (window as any).__adkInstallPrompt ?? null)
  const [dismissed, setDismissed] = useState(() => localStorage.getItem('adk_install_hint') === '1')
  const [showHow, setShowHow] = useState(false)

  useEffect(() => {
    const onInstallable = () => setDeferred((window as any).__adkInstallPrompt ?? null)
    const onInstalled = () => { setDismissed(true); localStorage.setItem('adk_install_hint', '1') }
    window.addEventListener('adk-installable', onInstallable)
    window.addEventListener('appinstalled', onInstalled)
    return () => {
      window.removeEventListener('adk-installable', onInstallable)
      window.removeEventListener('appinstalled', onInstalled)
    }
  }, [])

  const standalone =
    window.matchMedia('(display-mode: standalone)').matches ||
    (navigator as any).standalone === true
  if (standalone || dismissed) return null

  const ua = navigator.userAgent
  const isIOS = /iphone|ipad|ipod/i.test(ua)
  const iosSafari = isIOS && /safari/i.test(ua) && !/crios|fxios/i.test(ua)
  const isAndroid = /android/i.test(ua)

  const hide = () => { setDismissed(true); localStorage.setItem('adk_install_hint', '1') }
  const onInstall = async () => {
    if (deferred) {
      deferred.prompt()
      try { await deferred.userChoice } catch {}
      ;(window as any).__adkInstallPrompt = null
      setDeferred(null)
      hide()
      return
    }
    setShowHow((v) => !v) // bez nativního promptu ukaž ruční návod
  }

  // Ruční návod podle prohlížeče (když nativní prompt není).
  const manual = iosSafari ? (
    <>Klepni na <b>Sdílet</b> <span aria-hidden>⬆️</span> dole a zvol <b>Přidat na plochu</b>.</>
  ) : isIOS ? (
    <>Otevři tuhle stránku v <b>Safari</b>, pak <b>Sdílet</b> → <b>Přidat na plochu</b> (jiné prohlížeče to na iOS neumí).</>
  ) : isAndroid ? (
    <>Otevři <b>menu prohlížeče</b> (⋮ vpravo nahoře) a zvol <b>Instalovat aplikaci</b> nebo <b>Přidat na plochu</b>. V Brave: ⋮ → <b>Instalovat aplikaci</b>.</>
  ) : (
    <>V adresním řádku klikni na ikonu instalace, nebo <b>menu</b> (⋮) → <b>Instalovat aplikaci</b>.</>
  )

  return (
    <div className="install-hint">
      <div className="install-row">
        <span>📲 Nainstaluj appku na plochu (pohodlnější hraní)</span>
        <button onClick={onInstall}>{deferred ? 'Instalovat' : 'Jak na to'}</button>
        <button className="ghost x" onClick={hide} aria-label="Zavřít">×</button>
      </div>
      {showHow && !deferred && <div className="install-how">{manual}</div>}
    </div>
  )
}
