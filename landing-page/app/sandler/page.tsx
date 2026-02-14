'use client'

import AnnouncementBanner from '@/components/AnnouncementBanner'
import Navbar from '@/components/Navbar'
import SandlerHero from '@/components/SandlerHero'
import SocialProof from '@/components/SocialProof'
import Problem from '@/components/Problem'
import UVP from '@/components/UVP'
import Solution from '@/components/Solution'
import Features from '@/components/Features'
import HowItWorks from '@/components/HowItWorks'
import SandlerFrictionlessCoaching from '@/components/SandlerFrictionlessCoaching'
import TheScience from '@/components/TheScience'
import Qualification from '@/components/Qualification'
import Pricing from '@/components/Pricing'
import Testimonials from '@/components/Testimonials'
import FAQ from '@/components/FAQ'
import Contact from '@/components/Contact'
import FinalCTA from '@/components/FinalCTA'
import Footer from '@/components/Footer'
import Chatbot from '@/components/Chatbot'

export default function SandlerLandingPage() {
    return (
        <div className="min-h-screen">
            <AnnouncementBanner />
            <Navbar />
            <SandlerHero />
            <SocialProof />
            <Problem />
            <UVP />
            <Solution />
            <Features />
            <HowItWorks />
            <SandlerFrictionlessCoaching />
            <TheScience />
            <Qualification />
            <Pricing />
            <Testimonials />
            <FAQ />
            <Contact />
            <FinalCTA />
            <Footer />
            <Chatbot />
        </div>
    )
}
