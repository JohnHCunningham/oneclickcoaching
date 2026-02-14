'use client'

import AnnouncementBanner from '@/components/AnnouncementBanner'
import Navbar from '@/components/Navbar'
import Hero from '@/components/Hero'
import SocialProof from '@/components/SocialProof'
import SecurityBadges from '@/components/SecurityBadges'
import Problem from '@/components/Problem'
import UVP from '@/components/UVP'
import Solution from '@/components/Solution'
import Features from '@/components/Features'
import HowItWorks from '@/components/HowItWorks'
import FrictionlessCoaching from '@/components/FrictionlessCoaching'
import TheScience from '@/components/TheScience'
import Qualification from '@/components/Qualification'
import Pricing from '@/components/Pricing'
import Testimonials from '@/components/Testimonials'
import BlogPreview from '@/components/BlogPreview'
import FAQ from '@/components/FAQ'
import Contact from '@/components/Contact'
import FinalCTA from '@/components/FinalCTA'
import Footer from '@/components/Footer'
import Chatbot from '@/components/Chatbot'

export default function LandingPage() {
  return (
    <div className="min-h-screen">
      <AnnouncementBanner />
      <Navbar />
      <Hero />
      <SocialProof />
      <SecurityBadges variant="section" />
      <Problem />
      <UVP />
      <Solution />
      <Features />
      <HowItWorks />
      <FrictionlessCoaching />
      <TheScience />
      <Qualification />
      <Pricing />
      <Testimonials />
      <BlogPreview />
      <FAQ />
      <Contact />
      <FinalCTA />
      <Footer />
      <Chatbot />
    </div>
  )
}
