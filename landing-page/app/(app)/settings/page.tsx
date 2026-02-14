'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

interface AccountInfo {
  id: string
  name: string
  admin_designation: string | null
}

export default function SettingsPage() {
  const [account, setAccount] = useState<AccountInfo | null>(null)
  const [accountName, setAccountName] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const supabase = createClient()

  useEffect(() => {
    loadSettings()
  }, [])

  async function loadSettings() {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: currentUser } = await supabase
      .from('Users')
      .select('account_id')
      .eq('auth_id', user.id)
      .single()

    if (!currentUser) {
      setLoading(false)
      return
    }

    const { data: accountData } = await supabase
      .from('Accounts')
      .select('id, name, admin_designation')
      .eq('id', currentUser.account_id)
      .single()

    if (accountData) {
      setAccount(accountData)
      setAccountName(accountData.name || '')
    }
    setLoading(false)
  }

  async function handleSave() {
    if (!account) return
    setSaving(true)

    const { error } = await supabase
      .from('Accounts')
      .update({ name: accountName })
      .eq('id', account.id)

    if (!error) {
      setAccount({ ...account, name: accountName })
    }
    setSaving(false)
  }

  if (loading) {
    return <div className="text-light-muted">Loading settings...</div>
  }

  return (
    <div>
      <h1 className="text-3xl font-bold text-light mb-8">Settings</h1>

      <div className="max-w-2xl space-y-8">
        {/* Account Settings */}
        <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
          <h2 className="text-xl font-bold text-light mb-4">Account</h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-light mb-2">
                Company Name
              </label>
              <input
                type="text"
                value={accountName}
                onChange={(e) => setAccountName(e.target.value)}
                className="w-full px-4 py-3 bg-navy border border-teal/20 rounded-lg text-light focus:outline-none focus:border-teal focus:ring-2 focus:ring-teal/20"
              />
            </div>
            <button
              onClick={handleSave}
              disabled={saving || accountName === account?.name}
              className="bg-teal text-navy font-bold py-2.5 px-6 rounded-lg hover:bg-aqua transition-colors disabled:opacity-50"
            >
              {saving ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </div>

        {/* Methodology (Sandler-only) */}
        <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
          <h2 className="text-xl font-bold text-light mb-4">Methodology</h2>
          <div className="flex items-center gap-3 p-4 bg-teal/10 border border-teal/20 rounded-lg">
            <div className="w-10 h-10 bg-teal/20 rounded-full flex items-center justify-center text-teal font-bold">
              S
            </div>
            <div>
              <p className="font-semibold text-light">Sandler Selling System</p>
              <p className="text-sm text-light-muted">Active methodology for all coaching analysis</p>
            </div>
          </div>
        </div>

        {/* Danger Zone */}
        <div className="bg-navy-light rounded-2xl border border-pink/20 p-6">
          <h2 className="text-xl font-bold text-pink mb-4">Danger Zone</h2>
          <p className="text-light-muted text-sm mb-4">
            These actions are irreversible. Please be certain.
          </p>
          <button
            className="text-sm text-pink border border-pink/30 bg-pink/5 px-4 py-2 rounded-lg hover:bg-pink/10 transition-colors"
          >
            Delete Account
          </button>
        </div>
      </div>
    </div>
  )
}
