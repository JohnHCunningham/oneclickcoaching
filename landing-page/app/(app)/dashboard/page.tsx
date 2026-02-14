'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import Link from 'next/link'
import { HiUserGroup, HiPhone, HiAcademicCap, HiChartBar, HiTrendingUp, HiTrendingDown } from 'react-icons/hi'
import dynamic from 'next/dynamic'
import SandlerBreakdown from '../components/SandlerBreakdown'

const ScoreRadial = dynamic(() => import('../components/ScoreRadial'), { ssr: false })
const ScoreTrendChart = dynamic(() => import('../components/ScoreTrendChart'), { ssr: false })

interface UserInfo {
  role: string
  full_name: string
  email: string
  account_id: string
}

interface TeamStats {
  totalMembers: number
  totalCalls: number
  coachingSent: number
  avgScore: number | null
}

interface RepLeaderboard {
  email: string
  full_name: string
  avgScore: number
  callCount: number
}

interface CallScore {
  call_date: string
  methodology_scores: Record<string, number> | null
  rep_email: string | null
}

export default function DashboardPage() {
  const [userInfo, setUserInfo] = useState<UserInfo | null>(null)
  const [teamStats, setTeamStats] = useState<TeamStats>({ totalMembers: 0, totalCalls: 0, coachingSent: 0, avgScore: null })
  const [loading, setLoading] = useState(true)
  const [leaderboard, setLeaderboard] = useState<RepLeaderboard[]>([])
  const [trendLabels, setTrendLabels] = useState<string[]>([])
  const [trendScores, setTrendScores] = useState<number[]>([])
  const [repScores, setRepScores] = useState<Record<string, number> | null>(null)
  const [repCallScores, setRepCallScores] = useState<CallScore[]>([])
  const supabase = createClient()

  useEffect(() => {
    loadDashboard()
  }, [])

  async function loadDashboard() {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return

    const { data: userData } = await supabase
      .from('Users')
      .select('role, full_name, email, account_id')
      .eq('auth_id', user.id)
      .single()

    if (!userData) {
      setLoading(false)
      return
    }

    setUserInfo(userData)

    if (['admin', 'manager', 'coach'].includes(userData.role)) {
      await loadLeaderDashboard(userData.account_id)
    } else {
      await loadRepDashboard(userData.account_id, userData.email)
    }

    setLoading(false)
  }

  async function loadLeaderDashboard(accountId: string) {
    // Team member count
    const { count: memberCount } = await supabase
      .from('Users')
      .select('*', { count: 'exact', head: true })
      .eq('account_id', accountId)

    // Calls count
    const { count: callCount } = await supabase
      .from('Synced_Conversations')
      .select('*', { count: 'exact', head: true })
      .eq('account_id', accountId)
      .not('analyzed_at', 'is', null)

    // Coaching sent count
    const { count: coachingCount } = await supabase
      .from('Coaching_Messages')
      .select('*', { count: 'exact', head: true })
      .eq('account_id', accountId)
      .eq('status', 'sent')

    // Recent calls with scores for trend chart
    const { data: recentCalls } = await supabase
      .from('Synced_Conversations')
      .select('call_date, methodology_scores, rep_email')
      .eq('account_id', accountId)
      .not('methodology_scores', 'is', null)
      .order('call_date', { ascending: true })
      .limit(30)

    let avgScore: number | null = null

    if (recentCalls && recentCalls.length > 0) {
      // Build trend data (group by week)
      const weeklyScores: Record<string, number[]> = {}
      const repAggregates: Record<string, { sum: number; count: number; name: string }> = {}

      recentCalls.forEach((call) => {
        if (!call.methodology_scores) return
        const vals = Object.values(call.methodology_scores) as number[]
        if (vals.length === 0) return
        const avg = vals.reduce((a, b) => a + b, 0) / vals.length

        // Weekly aggregation
        const date = new Date(call.call_date)
        const weekKey = `${date.getMonth() + 1}/${date.getDate()}`
        if (!weeklyScores[weekKey]) weeklyScores[weekKey] = []
        weeklyScores[weekKey].push(avg)

        // Rep aggregation
        const rep = call.rep_email || 'unknown'
        if (!repAggregates[rep]) repAggregates[rep] = { sum: 0, count: 0, name: rep }
        repAggregates[rep].sum += avg
        repAggregates[rep].count += 1
      })

      // Trend
      const labels = Object.keys(weeklyScores)
      const scores = labels.map((k) => {
        const arr = weeklyScores[k]
        return Math.round(arr.reduce((a, b) => a + b, 0) / arr.length * 10) / 10
      })
      setTrendLabels(labels)
      setTrendScores(scores)

      // Overall avg
      const allScores = Object.values(weeklyScores).flat()
      avgScore = Math.round(allScores.reduce((a, b) => a + b, 0) / allScores.length * 10) / 10

      // Leaderboard
      const lb = Object.entries(repAggregates)
        .map(([email, data]) => ({
          email,
          full_name: email,
          avgScore: Math.round(data.sum / data.count * 10) / 10,
          callCount: data.count,
        }))
        .sort((a, b) => b.avgScore - a.avgScore)
      setLeaderboard(lb)
    }

    setTeamStats({
      totalMembers: memberCount || 0,
      totalCalls: callCount || 0,
      coachingSent: coachingCount || 0,
      avgScore,
    })
  }

  async function loadRepDashboard(accountId: string, email: string) {
    const { data: scores } = await supabase
      .from('Synced_Conversations')
      .select('call_date, methodology_scores, rep_email')
      .eq('account_id', accountId)
      .eq('rep_email', email)
      .not('methodology_scores', 'is', null)
      .order('call_date', { ascending: true })
      .limit(20)

    if (scores && scores.length > 0) {
      setRepCallScores(scores)

      // Calculate average scores
      const totals: Record<string, { sum: number; count: number }> = {}
      scores.forEach((s) => {
        if (s.methodology_scores) {
          Object.entries(s.methodology_scores).forEach(([key, val]) => {
            if (!totals[key]) totals[key] = { sum: 0, count: 0 }
            totals[key].sum += val as number
            totals[key].count += 1
          })
        }
      })
      const avgs: Record<string, number> = {}
      Object.entries(totals).forEach(([key, { sum, count }]) => {
        avgs[key] = Math.round((sum / count) * 10) / 10
      })
      setRepScores(avgs)

      // Trend
      const labels = scores.map((s) => new Date(s.call_date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }))
      const tScores = scores.map((s) => {
        if (!s.methodology_scores) return 0
        const vals = Object.values(s.methodology_scores) as number[]
        return vals.length ? Math.round(vals.reduce((a, b) => a + b, 0) / vals.length * 10) / 10 : 0
      })
      setTrendLabels(labels)
      setTrendScores(tScores)
    }
  }

  if (loading) {
    return <div className="text-light-muted">Loading dashboard...</div>
  }

  if (!userInfo) {
    return <div className="text-light-muted">Unable to load user data.</div>
  }

  const isLeader = ['admin', 'manager', 'coach'].includes(userInfo.role)
  const repOverallScore = repScores
    ? Math.round(Object.values(repScores).reduce((a, b) => a + b, 0) / Object.values(repScores).length * 10) / 10
    : null

  return (
    <div>
      <h1 className="text-3xl font-bold text-light mb-2">
        {isLeader ? 'Team Overview' : 'My Dashboard'}
      </h1>
      <p className="text-light-muted mb-8">
        Welcome back, {userInfo.full_name || 'there'}.
      </p>

      {isLeader ? (
        <>
          {/* Leader Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 bg-teal/20 rounded-lg flex items-center justify-center">
                  <HiUserGroup className="text-teal text-xl" />
                </div>
                <p className="text-sm text-light-muted">Team Members</p>
              </div>
              <p className="text-3xl font-bold text-light">{teamStats.totalMembers}</p>
            </div>

            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 bg-aqua/20 rounded-lg flex items-center justify-center">
                  <HiPhone className="text-aqua text-xl" />
                </div>
                <p className="text-sm text-light-muted">Calls Analyzed</p>
              </div>
              <p className="text-3xl font-bold text-light">{teamStats.totalCalls}</p>
            </div>

            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 bg-gold/20 rounded-lg flex items-center justify-center">
                  <HiAcademicCap className="text-gold text-xl" />
                </div>
                <p className="text-sm text-light-muted">Coaching Sent</p>
              </div>
              <p className="text-3xl font-bold text-light">{teamStats.coachingSent}</p>
            </div>

            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <div className="flex items-center gap-3 mb-3">
                <div className="w-10 h-10 bg-teal/20 rounded-lg flex items-center justify-center">
                  <HiChartBar className="text-teal text-xl" />
                </div>
                <p className="text-sm text-light-muted">Avg Sandler Score</p>
              </div>
              <p className="text-3xl font-bold text-light">
                {teamStats.avgScore !== null ? teamStats.avgScore : '--'}
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
            {/* Score Trends */}
            <div className="lg:col-span-2 bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">Score Trends</h2>
              {trendLabels.length > 1 ? (
                <ScoreTrendChart labels={trendLabels} scores={trendScores} height={250} />
              ) : (
                <p className="text-light-muted text-sm">
                  Team score trends will appear once calls are analyzed.
                </p>
              )}
            </div>

            {/* Quick Actions */}
            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">Quick Actions</h2>
              <div className="space-y-3">
                <Link
                  href="/app/team"
                  className="flex items-center gap-2 w-full bg-teal/10 text-teal border border-teal/20 px-4 py-3 rounded-lg hover:bg-teal/20 transition-colors text-sm font-medium"
                >
                  <HiUserGroup /> Manage Team
                </Link>
                <Link
                  href="/app/calls"
                  className="flex items-center gap-2 w-full bg-teal/10 text-teal border border-teal/20 px-4 py-3 rounded-lg hover:bg-teal/20 transition-colors text-sm font-medium"
                >
                  <HiPhone /> View Calls
                </Link>
                <Link
                  href="/app/integrations"
                  className="flex items-center gap-2 w-full bg-teal/10 text-teal border border-teal/20 px-4 py-3 rounded-lg hover:bg-teal/20 transition-colors text-sm font-medium"
                >
                  <HiChartBar /> Integrations
                </Link>
              </div>
            </div>
          </div>

          {/* Rep Leaderboard */}
          {leaderboard.length > 0 && (
            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">Rep Leaderboard</h2>
              <div className="space-y-2">
                {leaderboard.map((rep, i) => (
                  <div key={rep.email} className="flex items-center gap-4 p-3 rounded-lg hover:bg-navy/50 transition-colors">
                    <span className={`w-8 h-8 flex items-center justify-center rounded-full font-bold text-sm ${
                      i === 0 ? 'bg-gold/20 text-gold' : i === 1 ? 'bg-light-muted/20 text-light-muted' : i === 2 ? 'bg-orange-500/20 text-orange-400' : 'bg-navy text-light-muted'
                    }`}>
                      {i + 1}
                    </span>
                    <div className="flex-1">
                      <p className="text-sm font-medium text-light">{rep.full_name}</p>
                      <p className="text-xs text-light-muted">{rep.callCount} calls analyzed</p>
                    </div>
                    <span className={`text-lg font-bold ${rep.avgScore >= 7 ? 'text-teal' : rep.avgScore >= 5 ? 'text-gold' : 'text-pink'}`}>
                      {rep.avgScore}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </>
      ) : (
        <>
          {/* Rep View */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">My Sandler Score</h2>
              <div className="flex items-center justify-center py-4">
                {repOverallScore !== null ? (
                  <ScoreRadial score={repOverallScore} size={180} label="Overall" />
                ) : (
                  <div className="text-center">
                    <p className="text-5xl font-bold text-teal">--</p>
                    <p className="text-sm text-light-muted mt-2">Overall Score</p>
                    <p className="text-light-muted text-xs mt-4">
                      Your score will appear after your first call is analyzed.
                    </p>
                  </div>
                )}
              </div>
            </div>

            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">Component Breakdown</h2>
              {repScores ? (
                <SandlerBreakdown scores={repScores} />
              ) : (
                <p className="text-light-muted text-sm">
                  Component scores will appear after calls are analyzed.
                </p>
              )}
            </div>
          </div>

          {/* Score Trend */}
          <div className="bg-navy-light rounded-2xl border border-teal/10 p-6 mb-8">
            <h2 className="text-xl font-bold text-light mb-4">Score History</h2>
            {trendLabels.length > 1 ? (
              <ScoreTrendChart labels={trendLabels} scores={trendScores} height={200} />
            ) : (
              <p className="text-light-muted text-sm">
                Your score trend will appear after multiple calls are analyzed.
              </p>
            )}
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">Recent Coaching</h2>
              <p className="text-light-muted text-sm">
                Coaching messages from your manager will appear here.
              </p>
              <Link
                href="/app/coaching"
                className="inline-block mt-4 text-teal hover:text-aqua text-sm font-medium"
              >
                View All Coaching
              </Link>
            </div>

            <div className="bg-navy-light rounded-2xl border border-teal/10 p-6">
              <h2 className="text-xl font-bold text-light mb-4">My Calls</h2>
              <p className="text-light-muted text-sm">
                {repCallScores.length > 0
                  ? `${repCallScores.length} calls analyzed.`
                  : 'Your analyzed calls will appear here once integrations are configured.'}
              </p>
              <Link
                href="/app/calls"
                className="inline-block mt-4 text-teal hover:text-aqua text-sm font-medium"
              >
                View All Calls
              </Link>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
