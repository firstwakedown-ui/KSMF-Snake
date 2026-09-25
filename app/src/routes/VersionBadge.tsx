import { Link } from 'react-router-dom'
import { APP_VERSION } from '../lib/geo'

// Klikatelné číslo verze → info/„o aplikaci" stránka (kredity + deník vývoje).
export default function VersionBadge() {
  return <Link className="version-badge" to="/info">ⓘ {APP_VERSION}</Link>
}
