'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  HiHome,
  HiUserGroup,
  HiPhone,
  HiAcademicCap,
  HiPuzzle,
  HiChartBar,
  HiCog,
  HiSparkles,
} from 'react-icons/hi'

interface NavItem {
  href: string
  label: string
  icon: React.ComponentType<{ className?: string }>
  roles?: string[] // if undefined, visible to all roles
}

const navItems: NavItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: HiHome },
  { href: '/team', label: 'Team', icon: HiUserGroup, roles: ['admin', 'manager'] },
  { href: '/calls', label: 'Calls', icon: HiPhone },
  { href: '/coaching', label: 'Coaching', icon: HiAcademicCap },
  { href: '/integrations', label: 'Integrations', icon: HiPuzzle, roles: ['admin', 'manager'] },
  { href: '/goals', label: 'Goals', icon: HiChartBar },
  { href: '/celebrations', label: 'Celebrations', icon: HiSparkles },
  { href: '/settings', label: 'Settings', icon: HiCog, roles: ['admin'] },
]

export default function Sidebar({ userRole }: { userRole: string }) {
  const pathname = usePathname()

  const visibleItems = navItems.filter(
    (item) => !item.roles || item.roles.includes(userRole)
  )

  return (
    <aside className="w-64 bg-navy-dark border-r border-navy-light flex flex-col">
      <div className="p-6">
        <Link href="/dashboard" className="font-bold text-xl text-light">
          One Click<span className="text-teal"> Coaching</span>
        </Link>
      </div>

      <nav className="flex-1 px-3 space-y-1">
        {visibleItems.map((item) => {
          const Icon = item.icon
          const isActive = pathname.startsWith(item.href)
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-teal/10 text-teal'
                  : 'text-light-muted hover:text-light hover:bg-navy-light'
              }`}
            >
              <Icon className="text-lg" />
              {item.label}
            </Link>
          )
        })}
      </nav>

      <div className="p-4 border-t border-navy-light">
        <p className="text-xs text-light-muted text-center">One Click Coaching</p>
      </div>
    </aside>
  )
}
