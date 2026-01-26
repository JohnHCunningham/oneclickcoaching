import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { Toaster } from 'react-hot-toast'
import Analytics from '@/components/Analytics'

const inter = Inter({ subsets: ['latin'] })

const baseUrl = 'https://salesai.coach'

export const metadata: Metadata = {
  metadataBase: new URL(baseUrl),
  title: {
    default: 'AI Sales Coaching - Turn Every Call Into a Coaching Opportunity | Revenue Factory',
    template: '%s | Revenue Factory AI Sales Coaching',
  },
  description: 'AI-powered sales coaching that reinforces your methodology training. Get instant feedback on every call with MEDDIC, Sandler, Challenger, SPIN, or Gap Selling frameworks. Scale coaching without scaling headcount.',
  keywords: [
    'AI sales coaching',
    'sales methodology training',
    'MEDDIC coaching',
    'Sandler training reinforcement',
    'Challenger Sale coaching',
    'SPIN Selling AI',
    'Gap Selling methodology',
    'sales conversation analysis',
    'sales team coaching software',
    'revenue operations',
    'sales training ROI',
    'sales manager tools',
    'call coaching software',
    'sales performance analytics',
    'methodology execution tracking',
    'sales rep coaching',
    'B2B sales training',
    'enterprise sales coaching',
    'sales enablement platform',
    'conversation intelligence'
  ],
  authors: [{ name: 'Revenue Factory' }],
  creator: 'Revenue Factory',
  publisher: 'Revenue Factory',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: baseUrl,
    siteName: 'Revenue Factory - AI Sales Coaching',
    title: 'AI Sales Coaching - Finally Get ROI From Your Sales Training',
    description: 'AI coaching that reinforces what your trainers taught. Same-day feedback, every call, every rep. Scale coaching without scaling headcount.',
    images: [
      {
        url: '/og-image.jpg',
        width: 1200,
        height: 630,
        alt: 'Revenue Factory AI Sales Coaching Platform - Transform Your Sales Training ROI',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'AI Sales Coaching - Finally Get ROI From Your Sales Training',
    description: 'AI coaching that reinforces what your trainers taught. Same-day feedback, every call, every rep.',
    images: ['/og-image.jpg'],
    creator: '@revenuefactory',
  },
  alternates: {
    canonical: baseUrl,
  },
  category: 'Sales Software',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className={inter.className}>
        {children}
        <Toaster position="top-right" />
        <Analytics />
      </body>
    </html>
  )
}
