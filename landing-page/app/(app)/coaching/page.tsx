'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { HiMail, HiCheck, HiClock, HiEye } from 'react-icons/hi'

interface CoachingMessage {
  id: string
  rep_email: string
  manager_email: string
  status: string
  generated_at: string
  sent_at: string | null
  read_at: string | null
  coaching_content: string
  methodology: string
  rep_response: string | null
  responded_at: string | null
}

export default function CoachingPage() {
  const [messages, setMessages] = useState<CoachingMessage[]>([])
  const [loading, setLoading] = useState(true)
  const [userRole, setUserRole] = useState('')
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const supabase = createClient()

  useEffect(() => {
    loadCoaching()
  }, [])

  async function loadCoaching() {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: userData } = await supabase
      .from('Users')
      .select('account_id, role, email')
      .eq('auth_id', user.id)
      .single()

    if (!userData) {
      setLoading(false)
      return
    }

    setUserRole(userData.role)

    let query = supabase
      .from('Coaching_Messages')
      .select('*')
      .eq('account_id', userData.account_id)
      .order('generated_at', { ascending: false })
      .limit(50)

    // Reps only see coaching sent to them
    if (userData.role === 'rep') {
      query = query.eq('rep_email', userData.email)
    }

    const { data } = await query

    if (data) setMessages(data)
    setLoading(false)
  }

  async function handleSend(messageId: string) {
    const { error } = await supabase.functions.invoke('send-coaching-email', {
      body: { coaching_message_id: messageId },
    })

    if (!error) {
      loadCoaching()
    }
  }

  const statusConfig: Record<string, { label: string; color: string; icon: React.ComponentType<{ className?: string }> }> = {
    generated: { label: 'Draft', color: 'text-gold bg-gold/10 border-gold/20', icon: HiClock },
    approved: { label: 'Approved', color: 'text-teal bg-teal/10 border-teal/20', icon: HiCheck },
    sent: { label: 'Sent', color: 'text-aqua bg-aqua/10 border-aqua/20', icon: HiMail },
    read: { label: 'Read', color: 'text-green-400 bg-green-400/10 border-green-400/20', icon: HiEye },
    acknowledged: { label: 'Acknowledged', color: 'text-green-400 bg-green-400/10 border-green-400/20', icon: HiCheck },
  }

  if (loading) {
    return <div className="text-light-muted">Loading coaching...</div>
  }

  const isLeader = ['admin', 'manager', 'coach'].includes(userRole)

  return (
    <div>
      <h1 className="text-3xl font-bold text-light mb-2">Coaching</h1>
      <p className="text-light-muted mb-8">
        {isLeader ? 'Manage coaching messages for your team.' : 'Your coaching feedback.'}
      </p>

      {messages.length === 0 ? (
        <div className="bg-navy-light rounded-2xl border border-teal/10 p-8 text-center">
          <HiMail className="text-teal text-4xl mx-auto mb-4" />
          <h2 className="text-xl font-bold text-light mb-2">No coaching messages yet</h2>
          <p className="text-light-muted text-sm">
            {isLeader
              ? 'Coaching messages will be generated after calls are analyzed.'
              : 'Your coaching feedback will appear here.'}
          </p>
        </div>
      ) : (
        <div className="space-y-4">
          {messages.map((msg) => {
            const config = statusConfig[msg.status] || statusConfig.generated
            const StatusIcon = config.icon
            const isExpanded = expandedId === msg.id

            return (
              <div
                key={msg.id}
                className="bg-navy-light rounded-2xl border border-teal/10 overflow-hidden"
              >
                {/* Header */}
                <button
                  onClick={() => setExpandedId(isExpanded ? null : msg.id)}
                  className="w-full flex items-center gap-4 p-4 text-left hover:bg-navy/50 transition-colors"
                >
                  <div className="w-10 h-10 bg-teal/20 rounded-lg flex items-center justify-center">
                    <HiMail className="text-teal text-xl" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-light text-sm">
                      {isLeader ? `To: ${msg.rep_email}` : `From: ${msg.manager_email}`}
                    </p>
                    <p className="text-xs text-light-muted mt-0.5">
                      {new Date(msg.generated_at).toLocaleString()}
                      {msg.methodology && ` · ${msg.methodology}`}
                    </p>
                  </div>
                  <span className={`flex items-center gap-1 text-xs font-bold px-2.5 py-1 rounded-full border ${config.color}`}>
                    <StatusIcon className="text-sm" />
                    {config.label}
                  </span>
                </button>

                {/* Expanded Content */}
                {isExpanded && (
                  <div className="border-t border-navy px-4 pb-4">
                    <div className="pt-4">
                      <div className="bg-navy rounded-lg p-4 text-sm text-light-muted whitespace-pre-wrap">
                        {msg.coaching_content}
                      </div>

                      {msg.rep_response && (
                        <div className="mt-4">
                          <p className="text-xs font-bold text-light mb-2">Rep Response:</p>
                          <div className="bg-teal/5 border border-teal/10 rounded-lg p-3 text-sm text-light-muted">
                            {msg.rep_response}
                          </div>
                          <p className="text-xs text-light-muted mt-1">
                            Responded {msg.responded_at ? new Date(msg.responded_at).toLocaleString() : ''}
                          </p>
                        </div>
                      )}

                      {/* Actions for leaders */}
                      {isLeader && msg.status === 'generated' && (
                        <div className="mt-4 flex gap-3">
                          <button
                            onClick={() => handleSend(msg.id)}
                            className="flex items-center gap-2 bg-teal text-navy font-bold py-2 px-4 rounded-lg hover:bg-aqua transition-colors text-sm"
                          >
                            <HiMail /> Send to Rep
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
